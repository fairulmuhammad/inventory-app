# Inventory Service API Documentation

## Base URL
```
http://localhost:5001
```

## Endpoints

### Health Check
**GET** `/health`

Returns the health status of the service.

**Response:**
```json
{
    "status": "healthy",
    "timestamp": "2024-01-01T12:00:00.000Z",
    "version": "1.0.0",
    "inventory_count": 10
}
```

### Get All Items
**GET** `/items`

Retrieves all inventory items.

**Response:**
```json
{
    "items": [
        {
            "id": 1,
            "name": "Laptop",
            "stock": 10,
            "created_at": "2024-01-01T00:00:00Z"
        }
    ],
    "count": 1
}
```

### Get Item by ID
**GET** `/items/{id}`

Retrieves a specific item by ID.

**Parameters:**
- `id` (integer): Item ID

**Response:**
```json
{
    "id": 1,
    "name": "Laptop",
    "stock": 10,
    "created_at": "2024-01-01T00:00:00Z"
}
```

**Error Response (404):**
```json
{
    "error": "Item not found"
}
```

### Create Item
**POST** `/items`

Creates a new inventory item.

**Request Body:**
```json
{
    "name": "New Item",
    "stock": 100
}
```

**Response (201):**
```json
{
    "message": "Item added!",
    "item": {
        "id": 3,
        "name": "New Item",
        "stock": 100,
        "created_at": "2024-01-01T12:00:00Z"
    }
}
```

**Error Response (400):**
```json
{
    "error": "Missing required field: name"
}
```

### Update Item
**PUT** `/items/{id}`

Updates an existing item.

**Parameters:**
- `id` (integer): Item ID

**Request Body:**
```json
{
    "name": "Updated Item",
    "stock": 150
}
```

**Response:**
```json
{
    "message": "Item updated!",
    "item": {
        "id": 1,
        "name": "Updated Item",
        "stock": 150,
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T12:00:00Z"
    }
}
```

### Delete Item
**DELETE** `/items/{id}`

Deletes an item.

**Parameters:**
- `id` (integer): Item ID

**Response:**
```json
{
    "message": "Item deleted!",
    "deleted_item": {
        "id": 1,
        "name": "Laptop",
        "stock": 10,
        "created_at": "2024-01-01T00:00:00Z"
    }
}
```

### Metrics
**GET** `/metrics`

Returns Prometheus metrics for monitoring.

## Error Codes
- `200`: Success
- `201`: Created
- `400`: Bad Request (validation error)
- `404`: Not Found
- `500`: Internal Server Error

## Data Validation
- `name`: Required, non-empty string
- `stock`: Required, non-negative integer

## Examples

### cURL Examples
```bash
# Get all items
curl -X GET http://localhost:5001/items

# Create item
curl -X POST http://localhost:5001/items \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "stock": 50}'

# Update item
curl -X PUT http://localhost:5001/items/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Item", "stock": 75}'

# Delete item
curl -X DELETE http://localhost:5001/items/1
```

### Python Examples
```python
import requests

# Get all items
response = requests.get('http://localhost:5001/items')
items = response.json()

# Create item
new_item = {"name": "Python Item", "stock": 25}
response = requests.post('http://localhost:5001/items', json=new_item)
created_item = response.json()

# Update item
update_data = {"name": "Updated Python Item", "stock": 30}
response = requests.put(f'http://localhost:5001/items/{item_id}', json=update_data)
```
