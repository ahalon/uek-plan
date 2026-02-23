import requests
from bs4 import BeautifulSoup


dean_id = "252681"
base_url = "https://planzajec.uek.krakow.pl/index.php"

print(f"Pobieram surowy plan grupy dziekańskiej (ID: {dean_id})...")
res = requests.get(base_url, params={'typ': 'G', 'id': dean_id, 'okres': '1'})
soup = BeautifulSoup(res.text, 'html.parser')

table = soup.find('table')
if table:
    rows = table.find_all('tr')[1:] 
    print(f"Znaleziono {len(rows)} wszystkich wpisów. Filtruję lektoraty...\n")
    
    for row in rows:
        cols = row.find_all('td')
        if len(cols) >= 6:
            termin = cols[0].text.strip()
            przedmiot = cols[2].text.strip()
            typ = cols[3].text.strip()
            nauczyciel = cols[4].text.strip()
            sala = cols[5].text.strip()
            
            
            przedmiot_upper = przedmiot.upper()
            if "GERMAN" in przedmiot_upper or "LANGUAGE" in przedmiot_upper or "JĘZYK" in przedmiot_upper or "LEKTORAT" in typ.upper():
                print(f"[{termin}] | {przedmiot} | {nauczyciel} | Sala: {sala}")
else:
    print("Brak tabeli planu dla tej grupy.")