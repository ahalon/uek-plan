# UEK Schedule - API Scraper & Mobile App

A full-stack solution featuring a mobile application and a dedicated API designed to fetch and display real-time class schedules from the Cracow University of Economics (UEK) system. This project solves the issue of poor mobile responsiveness and difficult access to the official university schedule on smartphones.

## 🚀 Tech Stack

### Backend (API):
* **Python 3.10+**
* **FastAPI** - High-performance framework with automatic Swagger/OpenAPI documentation.
* **BeautifulSoup4 & lxml** - Robust web scraping for HTML parsing.
* **Requests** - HTTP client handling session management and Basic Authentication.
* **Uvicorn** - ASGI server implementation.

### Frontend (Mobile):
* **Flutter** - Multi-platform UI framework for a smooth user experience.
* **Dart** - For asynchronous JSON data fetching and state management.

## 🛠️ Architecture & Solutions
The project implements a middleware server (Backend) that authenticates with the university's system, parses raw HTML data, and serves clean, structured JSON endpoints for the mobile application.

**Key Features:**
- **IP Blacklisting Mitigation:** Optimized headers and session handling to bypass data center blocks.
- **Secure Authentication:** Implementation of Basic Auth required by the university's legacy system.
- **Smart Filtering:** Automated filtering for language courses, PE classes, and student associations.
- **Performance Optimization:** Minimized DOM tree traversal for fast scraping response times.

## 📦 Installation & Setup (Backend)

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YOUR-USERNAME/uek-plan.git](https://github.com/YOUR-USERNAME/uek-plan.git)
   cd uek-plan
2. **Create a virtual environment:**

    ```Bash
    python -m venv venv
    source venv/bin/activate  # Mac/Linux
    # venv\Scripts\activate  # Windows
    ```
3. **Install dependencies:**

    ```Bash
    pip install -r requirements.txt
    ```
4. **Configure environment variables (.env file):**

    ```.env
    UEK_LOGIN=your_student_id
    UEK_HASLO=your_password
    ```
5. **Run the server locally:**

    ```Bash
    uvicorn api:app --reload
    ```
## 🔐 Security & Privacy
Just like the official university website, access to the data through this app is restricted. Only students with valid UEK credentials (index number and password) can fetch the schedule. Authentication credentials (login/password) are handled strictly as environment variables and are never committed to the repository. The API acts as a secure tunnel and does not store any private user data.

## 📝 Author
**Adam Haloń** - Computer Science Student at the Cracow University of Economics.