from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import os
from dotenv import load_dotenv

load_dotenv() 

app = FastAPI()

UEK_LOGIN = os.getenv("UEK_LOGIN")
UEK_HASLO = os.getenv("UEK_HASLO")

@app.get("/plan/{group_id}")
def get_plan(group_id: str):
    if not UEK_LOGIN or not UEK_HASLO:
        raise HTTPException(status_code=500, detail="Brak danych logowania w pliku .env")

    url = f"https://planzajec.uek.krakow.pl/index.php?typ=G&id={group_id}&okres=1"
    
    response = requests.get(
        url, 
        auth=(UEK_LOGIN, UEK_HASLO), 
        headers={'User-Agent': 'Mozilla/5.0'}
    )

    response.encoding = 'utf-8'
    
    if response.status_code == 401:
        raise HTTPException(status_code=401, detail="Błąd 401: Złe hasło lub login w .env")
    elif response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail="Błąd połączenia z uczelnią")

    soup = BeautifulSoup(response.text, 'lxml')
    table = soup.find('table')
    
    if not table:
        return {"error": "Zalogowano pomyślnie, ale brak tabeli z planem"}
        
    plan = []
    rows = table.find_all('tr')[1:] 
    
    for row in rows:
        cols = row.find_all('td')
        if len(cols) >= 6:
            plan.append({
                "termin": cols[0].text.strip(),
                "dzien_godzina": cols[1].text.strip(),
                "przedmiot": cols[2].text.strip(),
                "typ": cols[3].text.strip(),
                "nauczyciel": cols[4].text.strip(),
                "sala": cols[5].text.strip()
            })
            
    return plan