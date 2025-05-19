# Links

```sh

curl -X POST https://devsecops-app.wittydesert-241b13c6.swedencentral.azurecontainerapps.io/v1/user -d '{"name": "John Doe", "email": "john.doe@example.com"}' -H "Content-Type: application/json"

curl https://devsecops-app.wittydesert-241b13c6.swedencentral.azurecontainerapps.io/v1/user/1 | jq

curl "https://devsecops-app.wittydesert-241b13c6.swedencentral.azurecontainerapps.io/v2/user/0%20OR%201=1" | jq

curl --insecure "https://devsecops-appgw.swedencentral.cloudapp.azure.com/v2/user/v2/user/0%20OR%201=1"

curl --insecure "https://devsecops-appgw.swedencentral.cloudapp.azure.com/v2/user/1%3B%20DROP%20TABLE%20users%3B--"

curl "https://devsecops-app.wittydesert-241b13c6.swedencentral.azurecontainerapps.io/v2/user/1%3B%20DROP%20TABLE%20users%3B--"

curl https://devsecops-app.wittydesert-241b13c6.swedencentral.azurecontainerapps.io/v2/user/1 | jq

```
