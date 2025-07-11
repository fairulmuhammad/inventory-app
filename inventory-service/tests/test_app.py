import pytest
import json
from app import app, inventory, validate_item_data

@pytest.fixture
def client():
    """Create a test client for the Flask application"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

@pytest.fixture
def sample_item():
    """Sample item data for testing"""
    return {
        "name": "Test Item",
        "stock": 100
    }

class TestHealthEndpoints:
    """Test health check endpoints"""
    
    def test_index(self, client):
        """Test the index endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert "message" in data
        assert "Inventory Service is running!" in data["message"]
        assert "timestamp" in data

    def test_health_check(self, client):
        """Test the health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data["status"] == "healthy"
        assert "timestamp" in data

class TestInventoryEndpoints:
    """Test inventory CRUD operations"""
    
    def test_get_all_items(self, client):
        """Test retrieving all items"""
        response = client.get("/items")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert "items" in data
        assert "count" in data
        assert isinstance(data["items"], list)
        assert data["count"] == len(data["items"])

    def test_get_existing_item(self, client):
        """Test retrieving an existing item by ID"""
        response = client.get("/items/1")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data["id"] == 1
        assert "name" in data
        assert "stock" in data

    def test_get_nonexistent_item(self, client):
        """Test retrieving a non-existent item"""
        response = client.get("/items/999")
        assert response.status_code == 404
        data = json.loads(response.data)
        assert "error" in data
        assert data["error"] == "Item not found"

    def test_add_valid_item(self, client, sample_item):
        """Test adding a valid item"""
        response = client.post("/items", 
                             data=json.dumps(sample_item),
                             content_type='application/json')
        assert response.status_code == 201
        data = json.loads(response.data)
        assert data["message"] == "Item added!"
        assert "item" in data
        assert data["item"]["name"] == sample_item["name"]
        assert data["item"]["stock"] == sample_item["stock"]
        assert "id" in data["item"]
        assert "created_at" in data["item"]

    def test_add_item_missing_name(self, client):
        """Test adding an item without name"""
        invalid_item = {"stock": 10}
        response = client.post("/items",
                             data=json.dumps(invalid_item),
                             content_type='application/json')
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "error" in data
        assert "Missing required field: name" in data["error"]

    def test_add_item_missing_stock(self, client):
        """Test adding an item without stock"""
        invalid_item = {"name": "Test Item"}
        response = client.post("/items",
                             data=json.dumps(invalid_item),
                             content_type='application/json')
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "error" in data
        assert "Missing required field: stock" in data["error"]

    def test_add_item_invalid_stock(self, client):
        """Test adding an item with invalid stock"""
        invalid_item = {"name": "Test Item", "stock": -1}
        response = client.post("/items",
                             data=json.dumps(invalid_item),
                             content_type='application/json')
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "error" in data
        assert "Stock must be a non-negative integer" in data["error"]

    def test_add_item_empty_name(self, client):
        """Test adding an item with empty name"""
        invalid_item = {"name": "", "stock": 10}
        response = client.post("/items",
                             data=json.dumps(invalid_item),
                             content_type='application/json')
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "error" in data
        assert "Name must be a non-empty string" in data["error"]

    def test_update_existing_item(self, client, sample_item):
        """Test updating an existing item"""
        # First add an item
        add_response = client.post("/items",
                                 data=json.dumps(sample_item),
                                 content_type='application/json')
        added_item = json.loads(add_response.data)["item"]
        item_id = added_item["id"]
        
        # Update the item
        updated_data = {"name": "Updated Item", "stock": 200}
        response = client.put(f"/items/{item_id}",
                            data=json.dumps(updated_data),
                            content_type='application/json')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data["message"] == "Item updated!"
        assert data["item"]["name"] == "Updated Item"
        assert data["item"]["stock"] == 200
        assert "updated_at" in data["item"]

    def test_update_nonexistent_item(self, client):
        """Test updating a non-existent item"""
        update_data = {"name": "Updated Item", "stock": 200}
        response = client.put("/items/999",
                            data=json.dumps(update_data),
                            content_type='application/json')
        assert response.status_code == 404
        data = json.loads(response.data)
        assert "error" in data
        assert data["error"] == "Item not found"

    def test_delete_existing_item(self, client, sample_item):
        """Test deleting an existing item"""
        # First add an item
        add_response = client.post("/items",
                                 data=json.dumps(sample_item),
                                 content_type='application/json')
        added_item = json.loads(add_response.data)["item"]
        item_id = added_item["id"]
        
        # Delete the item
        response = client.delete(f"/items/{item_id}")
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data["message"] == "Item deleted!"
        assert "deleted_item" in data

    def test_delete_nonexistent_item(self, client):
        """Test deleting a non-existent item"""
        response = client.delete("/items/999")
        assert response.status_code == 404
        data = json.loads(response.data)
        assert "error" in data
        assert data["error"] == "Item not found"

class TestDataValidation:
    """Test data validation functions"""
    
    def test_validate_valid_item(self):
        """Test validation with valid item data"""
        valid_data = {"name": "Test Item", "stock": 10}
        is_valid, message = validate_item_data(valid_data)
        assert is_valid == True
        assert message == "Valid"

    def test_validate_missing_name(self):
        """Test validation with missing name"""
        invalid_data = {"stock": 10}
        is_valid, message = validate_item_data(invalid_data)
        assert is_valid == False
        assert "Missing required field: name" in message

    def test_validate_missing_stock(self):
        """Test validation with missing stock"""
        invalid_data = {"name": "Test Item"}
        is_valid, message = validate_item_data(invalid_data)
        assert is_valid == False
        assert "Missing required field: stock" in message

    def test_validate_negative_stock(self):
        """Test validation with negative stock"""
        invalid_data = {"name": "Test Item", "stock": -5}
        is_valid, message = validate_item_data(invalid_data)
        assert is_valid == False
        assert "Stock must be a non-negative integer" in message

    def test_validate_empty_name(self):
        """Test validation with empty name"""
        invalid_data = {"name": "", "stock": 10}
        is_valid, message = validate_item_data(invalid_data)
        assert is_valid == False
        assert "Name must be a non-empty string" in message

    def test_validate_none_data(self):
        """Test validation with None data"""
        is_valid, message = validate_item_data(None)
        assert is_valid == False
        assert "No data provided" in message

if __name__ == "__main__":
    pytest.main([__file__])
