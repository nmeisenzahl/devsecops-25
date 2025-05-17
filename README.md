# devsecops-25

### Instructions to Build, Configure, and Run the Application

#### Prerequisites
- Golang 1.16 or later
- Docker
- Azure account with an Azure SQL Database and User-assigned Managed Identity

#### Steps

1. **Clone the repository:**
   ```sh
   git clone https://github.com/nmeisenzahl/devsecops-25.git
   cd devsecops-25
   ```

2. **Set up environment variables:**
   Create a `.env` file in the root directory and add the following environment variables:
   ```sh
   DB_SERVER=<your-azure-sql-server>
   DB_DATABASE=<your-database-name>
   ```

3. **Get all dependencies ready:**
   ```sh
   go mod tidy
   ```

4. **Build the application:**
   ```sh
   go build -o main .
   ```

5. **Run the application:**
   ```sh
   ./main
   ```

6. **Build the Docker image:**
   ```sh
   docker build -t devsecops-25 .
   ```

7. **Run the Docker container:**
   ```sh
   docker run -p 8080:8080 --env-file .env devsecops-25
   ```

8. **Access the API:**
   The API will be available at `http://localhost:8080`. You can use tools like `curl` or Postman to interact with the endpoints.

   - **Create a user:**
     ```sh
     curl -X POST http://localhost:8080/user -d '{"name": "John Doe", "email": "john.doe@example.com"}' -H "Content-Type: application/json"
     ```

   - **Get a user:**
     ```sh
     curl http://localhost:8080/user/1
     ```

   - **Update a user:**
     ```sh
     curl -X PUT http://localhost:8080/user/1 -d '{"name": "Jane Doe", "email": "jane.doe@example.com"}' -H "Content-Type: application/json"
     ```

   - **Delete a user:**
     ```sh
     curl -X DELETE http://localhost:8080/user/1
     ```
