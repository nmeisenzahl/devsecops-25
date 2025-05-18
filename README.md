# DevSecOps Demo

This repo contains a demo application to showcase some DevSecOps practices. Therefore this repo contains some antipatterns!

### Demo Application

#### Prerequisites
- Golang
- Docker (or similar container runtime)
- Azure CLI
- Azure subscription with an Azure SQL Database

#### Build and Run the Application

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
   The API endpoints will be available under the `/v1` prefix at `http://localhost:8080/v1`.

   - **Create a user:**
     ```sh
     curl -X POST http://localhost:8080/v1/user -d '{"name": "John Doe", "email": "john.doe@example.com"}' -H "Content-Type: application/json"
     ```

   - **Get a user:**
     ```sh
     curl http://localhost:8080/v1/user/1
     ```

   - **Update a user:**
     ```sh
     curl -X PUT http://localhost:8080/v1/user/1 -d '{"name": "Jane Doe", "email": "jane.doe@example.com"}' -H "Content-Type: application/json"
     ```

   - **Delete a user:**
     ```sh
     curl -X DELETE http://localhost:8080/v1/user/1
     ```

### Vulnerable SQL Injection Demo (v2 endpoint)

The v2 endpoint is intentionally vulnerable to SQL injection for demonstration purposes. Use with caution.

- **Get a user (vulnerable):**

  ```sh
  curl http://localhost:8080/v2/user/1
  ```

- **SQL Injection Example:**

    ```sh
    curl "http://localhost:8080/v2/user/1%3B%20DROP%20TABLE%20users%3B--"  # spaces must be URL-encoded
    ```

  This payload demonstrates a classic SQL injection attack by attempting to drop the `users` table.
    The SQL query would look like this:

    ```sql
    SELECT * FROM users WHERE id = '1'; DROP TABLE users;--'
    ```

### Azure Infrastructure

The `src/infra` folder contains Terraform code to provision the required Azure resources.

To deploy the infrastructure:

```bash
# Change to the infra directory
cd src/infra

# Export your Azure subscription ID into the environment for Terraform
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# If you’re using OIDC-based authentication with Terraform, export the OIDC subject as a variable
export TF_VAR_oidc_subject="repo:octo-org/octo-repo:ref:refs/heads/main"

# Initialize Terraform (downloads providers, sets up backend)
terraform init

# Preview changes
terraform plan

# Apply infrastructure changes
terraform apply \
  -auto-approve 
```

After apply completes, Terraform will output the resource group name and location.

To destroy the resources when you are done:

```bash
terraform destroy \
  -auto-approve
```
````
