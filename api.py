from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import urllib.parse as urlparse
import os
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

UEK_LOGIN = os.getenv("UEK_LOGIN")
UEK_HASLO = os.getenv("UEK_HASLO")

BASE_URL = "https://planzajec.uek.krakow.pl/index.php"
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

def get_soup(url, params=None):
    response = requests.get(
        url, 
        params=params, 
        headers=HEADERS, 
        auth=(UEK_LOGIN, UEK_HASLO), 
        timeout=15
    )
    response.encoding = 'utf-8'
    if response.status_code != 200:
        print(f"BŁĄD HTTP: {response.status_code} dla {url}")
        return None
    return BeautifulSoup(response.text, 'lxml')

@app.get("/groups")
def get_all_groups():
    try:
        soup = get_soup(BASE_URL)
        if not soup:
            raise HTTPException(status_code=401, detail="Błąd autoryzacji")

        category_links = []
        for a in soup.find_all('a', href=True):
            if 'typ=G' in a['href'] and 'grupa=' in a['href']:
                full_cat_url = urlparse.urljoin(BASE_URL, a['href'])
                cat_name = a.text.strip().upper()
                category_links.append((full_cat_url, cat_name))

        all_groups = []
        for cat_url, cat_name in category_links:
            cat_soup = get_soup(cat_url)
            if not cat_soup: continue

            for a in cat_soup.find_all('a', href=True):
                href = a['href']
                if 'id=' in href and 'typ=G' in href:
                    full_group_url = urlparse.urljoin(BASE_URL, href)
                    parsed = urlparse.urlparse(full_group_url)
                    group_id = urlparse.parse_qs(parsed.query).get('id', [None])[0]
                    name = a.text.strip()
                    
                    if group_id and name:
                        is_wf = "SWFIS" in cat_name or "AZS" in cat_name
                        is_lang = "CENTRUM JĘZYKOWE" in cat_name
                        
                        all_groups.append({
                            "name": name, 
                            "id": group_id,
                            "is_wf": is_wf,
                            "is_lang": is_lang
                        })

        unique_groups = list({v['id']: v for v in all_groups}.values())
        return sorted(unique_groups, key=lambda x: x['name'])

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/plan/{group_id}")
def get_plan(group_id: str):
    params = {'typ': 'G', 'id': group_id, 'okres': '2'}
    try:
        soup = get_soup(BASE_URL, params=params)
        if not soup: return []
        
        table = soup.find('table')
        if not table: return []
        
        plan = []
        rows = table.find_all('tr')[1:]
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
            
            elif len(cols) == 1 and len(plan) > 0:
                uwaga = cols[0].text.strip()
                if uwaga:
                    plan[-1]["uwagi"] = uwaga
                    
        return plan
    except Exception as e:
        return {"error": str(e)}