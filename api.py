from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import urllib.parse as urlparse
import os
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

# Pobieranie danych z .env
UEK_LOGIN = os.getenv("UEK_LOGIN")
UEK_HASLO = os.getenv("UEK_HASLO")

BASE_URL = "https://planzajec.uek.krakow.pl/index.php"

# Rozbudowane nagłówki, żeby udawać realnego użytkownika
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
}

def get_soup(url, params=None):
    try:
        # Usunąłem auth=(), bo serwer UEK odrzuca Basic Auth i sypie 401
        response = requests.get(
            url, 
            params=params, 
            headers=HEADERS, 
            timeout=10
        )
        response.encoding = 'utf-8'
        
        if response.status_code != 200:
            print(f"BŁĄD HTTP: {response.status_code} dla {url}")
            return None
            
        return BeautifulSoup(response.text, 'lxml')
    except Exception as e:
        print(f"Błąd połączenia: {e}")
        return None

@app.get("/groups")
def get_all_groups():
    try:
        soup = get_soup(BASE_URL)
        if not soup:
            raise HTTPException(status_code=503, detail="Nie można połączyć się z serwerem UEK")

        all_groups = []
        # Szukamy linków bezpośrednio, bez wchodzenia w każdą kategorię (oszczędność czasu i IP)
        for a in soup.find_all('a', href=True):
            href = a['href']
            # Wyłapujemy tylko linki do konkretnych grup (id=... i typ=G)
            if 'id=' in href and 'typ=G' in href:
                parsed = urlparse.urlparse(href)
                params = urlparse.parse_qs(parsed.query)
                group_id = params.get('id', [None])[0]
                name = a.text.strip()
                
                if group_id and name:
                    all_groups.append({
                        "name": name, 
                        "id": group_id,
                        "is_wf": "WF" in name.upper() or "AZS" in name.upper(),
                        "is_lang": "LEKTORAT" in name.upper() or "JĘZYK" in name.upper()
                    })

        if not all_groups:
            # Jeśli lista pusta, spróbujmy głębiej w kategorie (fallback)
            return {"status": "error", "message": "Nie znaleziono grup. Serwer UEK może blokować scraper."}

        # Usuwanie duplikatów i sortowanie
        unique_groups = list({v['id']: v for v in all_groups}.values())
        return sorted(unique_groups, key=lambda x: x['name'])

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Błąd serwera: {str(e)}")

@app.get("/plan/{group_id}")
def get_plan(group_id: str):
    # okres=2 oznacza bieżący semestr
    params = {'typ': 'G', 'id': group_id, 'okres': '2'}
    try:
        soup = get_soup(BASE_URL, params=params)
        if not soup: 
            raise HTTPException(status_code=503, detail="Błąd pobierania planu")
        
        table = soup.find('table')
        if not table: return []
        
        plan = []
        rows = table.find_all('tr')[1:] # Pomijamy nagłówek tabeli
        
        for row in rows:
            cols = row.find_all('td')
            if len(cols) >= 6:
                termin = cols[0].text.strip()
                plan.append({
                    "data": termin.split(' ')[0] if ' ' in termin else termin,
                    "godzina": cols[1].text.strip(),
                    "przedmiot": cols[2].text.strip(),
                    "typ": cols[3].text.strip(),
                    "nauczyciel": cols[4].text.strip(),
                    "sala": cols[5].text.strip(),
                    "uwagi": ""
                })
            elif len(cols) == 1 and plan:
                # Obsługa uwag w planie (często w osobnych wierszach)
                uwaga = cols[0].text.strip()
                if uwaga:
                    plan[-1]["uwagi"] = uwaga
                    
        return plan
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)