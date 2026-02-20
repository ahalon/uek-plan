from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import os
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

UEK_LOGIN = os.getenv("UEK_LOGIN")
UEK_HASLO = os.getenv("UEK_HASLO")

@app.get("/groups")
def get_groups():
    url = "https://planzajec.uek.krakow.pl/index.php"
    try:
        response = requests.get(url, auth=(UEK_LOGIN, UEK_HASLO), timeout=10)
        soup = BeautifulSoup(response.text, 'lxml')
        select = soup.find('select', {'id': 'id'})
        if not select:
            return []
        
        groups = []
        for option in select.find_all('option'):
            name = option.text.strip()
            val = option.get('value')
            if val and name:
                groups.append({"name": name, "id": val})
        return groups
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/plan/{group_id}")
def get_plan(group_id: str):
    url = f"https://planzajec.uek.krakow.pl/index.php?typ=G&id={group_id}&okres=1"
    response = requests.get(url, auth=(UEK_LOGIN, UEK_HASLO))
    response.encoding = 'utf-8'
    
    soup = BeautifulSoup(response.text, 'lxml')
    table = soup.find('table')
    if not table: return []
        
    plan = []
    rows = table.find_all('tr')[1:] 
    for row in rows:
        cols = row.find_all('td')
        if len(cols) >= 6:
            termin = cols[0].text.strip()
            data = termin.split(' ')[0] if ' ' in termin else termin
            plan.append({
                "data": data,
                "godzina": cols[1].text.strip(),
                "przedmiot": cols[2].text.strip(),
                "typ": cols[3].text.strip(),
                "sala": cols[5].text.strip()
            })
    return plan