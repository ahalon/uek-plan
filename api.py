from fastapi import FastAPI, HTTPException
import requests
from bs4 import BeautifulSoup
import urllib.parse as urlparse
import os
from dotenv import load_dotenv

# loads environment variables from .env
load_dotenv()

# initializes FastApi instance
app = FastAPI()

# Fetches data from .env
UEK_LOGIN = os.getenv("UEK_LOGIN")
UEK_HASLO = os.getenv("UEK_HASLO")

# Entry point for all scraping requests to the UEK legacy system
BASE_URL = "https://planzajec.uek.krakow.pl/index.php"

# HTTP headers to mimic a real web browser and avoid being blocked as a bot
HEADERS = {
    # Identidies the request as coming from a specific browser and OS
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    # Specifies the types of content the client can process
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    # Informs the sever about the preferred language for the response
    'Accept-Language': 'pl-PL,pl;q=0.9,en-US;q=0.8,en;q=0.7',
}

def get_soup(url, params=None):
    """
    Fetches and parses HTML content from a given URL.

    Args:
        url (str): The target URL to fetch data from.
        params (dict, optional): URL parameters for the request.

    Returns:
        BeautifulSoup: A parsed object if successful, None if an error occurs.
    """
    try:
        auth = (UEK_LOGIN, UEK_HASLO) if UEK_LOGIN and UEK_HASLO else None
        # Execute the GET request with custom headers and a 10-second safety timeout
        response = requests.get(
            url, 
            params=params, 
            headers=HEADERS, 
            auth=auth,
            timeout=10
        )
        # Force utf-8 to handle polish characters
        response.encoding = 'utf-8'
        
        #Check if the server responded succesfully
        if response.status_code != 200:
            print(f"BŁĄD HTTP: {response.status_code} dla {url}")
            return None

        # BeautifulSoup transforms raw HTML into a navigable object (DOM Tree),
        # allowing us to search for specific tags and extract their data.   
        return BeautifulSoup(response.text, 'lxml')
    # Error handle
    except Exception as e:
        print(f"Błąd połączenia: {e}")
        return None

@app.get("/groups")
def get_all_groups():
    """
    Scrapes the university portal to retrieve and categorize all student groups.
    """
    try:
        # Fetch the parsed HTML 'soup' from the base schedule URL
        soup = get_soup(BASE_URL)
        if not soup:
            # Raise service unavailable error if the university server doesn't respond
            raise HTTPException(status_code=503, detail="Nie można połączyć się z serwerem UEK")

        all_groups = []
        # Iterate through all hyperlinks to find group-specific data
        for a in soup.find_all('a', href=True):
            href = a['href']
            
            # Filter for links containing both an ID and the 'Group' type parameter
            if 'id=' in href and 'typ=G' in href:
                # Parse the query string to safely extract the 'id' value
                parsed = urlparse.urlparse(href)
                params = urlparse.parse_qs(parsed.query)
                group_id = params.get('id', [None])[0]
                name = a.text.strip()
                
                if group_id and name:
                    # Append group data with boolean flags for PE and Language courses
                    all_groups.append({
                        "name": name, 
                        "id": group_id,
                        "is_wf": "WF" in name.upper() or "AZS" in name.upper(),
                        "is_lang": "LEKTORAT" in name.upper() or "JĘZYK" in name.upper()
                    })

        if not all_groups:
            # Fallback error if the scraper finds no groups (potential block or layout change)
            raise HTTPException(status_code=503, detail="Nie znaleziono grup. Serwer UEK może blokować scraper.")

        # Remove duplicates using a dictionary comprehension and sort the list alphabetically
        unique_groups = list({v['id']: v for v in all_groups}.values())
        return sorted(unique_groups, key=lambda x: x['name'])

    except HTTPException:
        raise
    except Exception as e:
        # Global catch-all for server-side errors
        raise HTTPException(status_code=500, detail=f"Błąd serwera: {str(e)}")

@app.get("/plan/{group_id}")
def get_plan(group_id: str):
    """
    Fetches and parses the detailed schedule for a specific group ID.
    """
    # Define request parameters: Group type, unique ID, and time period
    params = {'typ': 'G', 'id': group_id, 'okres': '2'}
    try:
        # Fetch the parsed HTML from the university server
        soup = get_soup(BASE_URL, params=params)
        if not soup: 
            raise HTTPException(status_code=503, detail="Błąd pobierania planu")
        
        # Locate the primary schedule table within the page content
        table = soup.find('table')
        if not table: return []
        
        plan = []
        # Extract all table rows, skipping the first row (header labels)
        rows = table.find_all('tr')[1:]
        
        for row in rows:
            # Find all table cells (columns) in the current row
            cols = row.find_all('td')
            
            # Process rows with 6+ columns as standard lesson entries
            if len(cols) >= 6:
                termin = cols[0].text.strip()
                plan.append({
                    # Extract only the date part if a weekday name is present
                    "data": termin.split(' ')[0] if ' ' in termin else termin,
                    "godzina": cols[1].text.strip(),
                    "przedmiot": cols[2].text.strip(),
                    "typ": cols[3].text.strip(),
                    "nauczyciel": cols[4].text.strip(),
                    "sala": cols[5].text.strip(),
                    "uwagi": ""
                })
            # Handle special notice rows (single column) by attaching them to the last lesson
            elif len(cols) == 1 and plan:
                uwaga = cols[0].text.strip()
                if uwaga:
                    plan[-1]["uwagi"] = uwaga
                    
        return plan
    except HTTPException:
        raise
    except Exception as e:
        # Catch and return runtime errors as proper HTTP responses
        raise HTTPException(status_code=500, detail=f"Błąd serwera: {str(e)}")


# Entry point: Starts the Uvicorn ASGI server on all network interfaces (0.0.0.0) 
# to allow access from mobile devices on the same network via port 8000.
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)