import os
import sqlite3
import sqlite_vec
from sqlite_vec import serialize_float32
import uuid
import csv
import re
from sentence_transformers import SentenceTransformer
from tqdm import tqdm

def chunk_text(text, min_words=300, max_words=500):
    paragraphs = text.split('\n')
    chunks = []
    current_chunk = []
    current_words = 0
    
    for p in paragraphs:
        p = p.strip()
        if not p:
            continue
        words = len(p.split())
        if current_words + words > max_words and current_words >= min_words:
            chunks.append("\n".join(current_chunk))
            current_chunk = [p]
            current_words = words
        else:
            current_chunk.append(p)
            current_words += words
            
        if current_words >= max_words:
            chunks.append("\n".join(current_chunk))
            current_chunk = []
            current_words = 0
            
    if current_chunk:
        chunks.append("\n".join(current_chunk))
        
    return chunks

def init_db(conn):
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    conn.enable_load_extension(False)
    
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS decisions (
            case_number TEXT PRIMARY KEY,
            real_id TEXT,
            category TEXT,
            date TEXT,
            subject TEXT,
            result TEXT,
            full_text TEXT
        )
    ''')
    
    cursor.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS decisions_fts USING fts5(
            case_number UNINDEXED,
            real_id UNINDEXED,
            category UNINDEXED,
            date UNINDEXED,
            subject,
            result,
            full_text
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS chunks (
            chunk_rowid INTEGER PRIMARY KEY AUTOINCREMENT,
            chunk_id TEXT UNIQUE,
            case_number TEXT,
            chunk_index INTEGER,
            chunk_text TEXT,
            FOREIGN KEY(case_number) REFERENCES decisions(case_number)
        )
    ''')
    
    cursor.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
            chunk_rowid INTEGER PRIMARY KEY,
            embedding float[1024]
        )
    ''')
    conn.commit()

def extract_real_id(url):
    match = re.search(r'/download/(\d+)', url)
    if match:
        return match.group(1)
    return "" 

def load_csv_metadata(csv_path, category):
    metadata = {}
    if not os.path.exists(csv_path):
        print(f"Warning: CSV not found at {csv_path}")
        return metadata
        
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            case_number = row.get('Case Number', '').strip()
            if not case_number:
                continue
                
            real_id = extract_real_id(row.get('Download URL', ''))
            subject = row.get('Subject', '').replace('\n', ' ').replace('\r', ' ').strip()
            
            metadata[case_number] = {
                'real_id': real_id,
                'date': row.get('Date', '').strip(),
                'subject': subject,
                'result': row.get('Result', '').strip(),
                'category': category
            }
    return metadata

def process_category(data_dir, csv_path, category_name, db_path, embedding_model):
    print(f"\n--- Processing {category_name} Cases ---")
    
    meta = load_csv_metadata(csv_path, category_name)
    
    all_files = []
    if os.path.exists(data_dir):
        for root, _, files in os.walk(data_dir):
            for f in files:
                if f.lower().endswith('.txt'):
                    case_number = f[:-4].strip()
                    all_files.append({
                        'path': os.path.join(root, f),
                        'case_number': case_number,
                        'meta': meta.get(case_number)
                    })
    
    if not all_files:
        print(f"No .txt files found in {data_dir}.")
        return

    conn = sqlite3.connect(db_path)
    init_db(conn)
    cursor = conn.cursor()
    
    # Resume functionality
    cursor.execute("SELECT case_number FROM decisions")
    processed_cases = set(row[0] for row in cursor.fetchall())
    
    batch_size = 50
    current_batch_files = 0
    
    print(f"Found {len(all_files)} files. {len(processed_cases)} already processed.")
    
    for item in tqdm(all_files, desc=f"Indexing {category_name}"):
        file_path = item['path']
        case_number = item['case_number']
        m = item['meta']
        
        if case_number in processed_cases:
            continue
            
        real_id = m['real_id'] if m else ""
        date = m['date'] if m else ""
        subject = m['subject'] if m else ""
        result = m['result'] if m else ""
            
        try:
            cursor.execute("SAVEPOINT file_sp")
            
            with open(file_path, 'r', encoding='utf-8') as f:
                full_text = f.read()
                
            cursor.execute('''
                INSERT INTO decisions (case_number, real_id, category, date, subject, result, full_text)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (case_number, real_id, category_name, date, subject, result, full_text))
            
            cursor.execute('''
                INSERT INTO decisions_fts (case_number, real_id, category, date, subject, result, full_text)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (case_number, real_id, category_name, date, subject, result, full_text))
            
            chunks = chunk_text(full_text)
            
            if chunks:
                embeddings = embedding_model.encode(chunks, batch_size=4, normalize_embeddings=True)
                
                for chunk_index, (chunk_txt, emb) in enumerate(zip(chunks, embeddings)):
                    chunk_id = str(uuid.uuid4())
                    
                    cursor.execute('''
                        INSERT INTO chunks (chunk_id, case_number, chunk_index, chunk_text)
                        VALUES (?, ?, ?, ?)
                    ''', (chunk_id, case_number, chunk_index, chunk_txt))
                    
                    chunk_rowid = cursor.lastrowid
                    
                    cursor.execute('''
                        INSERT INTO vec_chunks (chunk_rowid, embedding)
                        VALUES (?, ?)
                    ''', (chunk_rowid, serialize_float32(emb.tolist())))
                    
            cursor.execute("RELEASE SAVEPOINT file_sp")
            
            current_batch_files += 1
            if current_batch_files >= batch_size:
                conn.commit()
                current_batch_files = 0
                
        except Exception as e:
            cursor.execute("ROLLBACK TO SAVEPOINT file_sp")
            tqdm.write(f"Error processing {case_number}: {e}")
            
    conn.commit()
    conn.close()

if __name__ == "__main__":
    ADMIN_DIR = r"C:\Users\facke\OneDrive\Desktop\BIG DATA\ADMINISTRATIVE\ALL"
    ADMIN_CSV = r"C:\Users\facke\OneDrive\Desktop\BIG DATA\ADMINISTRATIVE\ადმინისტრაციული_2026-05-31_13-33.csv"
    ADMIN_DB_PATH = r"C:\Coding Projects\PROTOTYPE XKIL\admin_decisions.db"
    
    CIVIL_DIR = r"C:\Users\facke\OneDrive\Desktop\BIG DATA\CIVIL\ALL CASES"
    CIVIL_CSV = r"C:\Users\facke\OneDrive\Desktop\BIG DATA\CIVIL\სამოქალაქო_2026-05-31_18-08.csv"
    CIVIL_DB_PATH = r"C:\Coding Projects\PROTOTYPE XKIL\civil_decisions.db"
    
    print("Loading embedding model (BAAI/bge-m3) on GPU...")
    try:
        embedding_model = SentenceTransformer("BAAI/bge-m3", device="cuda", model_kwargs={"use_safetensors": True})
        print("Successfully loaded model on GPU!")
    except Exception as e:
        print(f"Error loading on GPU: {e}")
        print("Falling back to CPU... (This will be very slow!)")
        embedding_model = SentenceTransformer("BAAI/bge-m3", device="cpu", model_kwargs={"use_safetensors": True})

    # Process Civil
    process_category(CIVIL_DIR, CIVIL_CSV, "Civil", CIVIL_DB_PATH, embedding_model)
    
    # Process Administrative
    process_category(ADMIN_DIR, ADMIN_CSV, "Administrative", ADMIN_DB_PATH, embedding_model)
    
    print("\nAll indexing complete!")
