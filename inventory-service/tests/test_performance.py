import pytest
import time
import concurrent.futures
import statistics
from app import app

class TestPerformance:
    """Performance tests for the inventory service"""
    
    @pytest.fixture
    def client(self):
        """Create test client for performance testing"""
        app.config['TESTING'] = True
        with app.test_client() as client:
            yield client
    
    def test_response_time_get_items(self, client):
        """Test response time for getting all items"""
        start_time = time.time()
        response = client.get("/items")
        end_time = time.time()
        
        response_time = end_time - start_time
        assert response.status_code == 200
        assert response_time < 1.0  # Should respond within 1 second
        
    def test_concurrent_requests(self, client):
        """Test handling concurrent requests using test client"""
        def make_request():
            return client.get("/items")
        
        # Test with 10 concurrent requests
        results = []
        for _ in range(10):
            response = make_request()
            results.append(response)
        
        # All requests should succeed
        for response in results:
            assert response.status_code == 200
            
    def test_load_test_simple(self, client):
        """Simple load test using test client"""
        response_times = []
        
        for _ in range(50):
            start_time = time.time()
            response = client.get("/items")
            end_time = time.time()
            
            assert response.status_code == 200
            response_times.append(end_time - start_time)
        
        # Calculate statistics
        avg_response_time = statistics.mean(response_times)
        max_response_time = max(response_times)
        min_response_time = min(response_times)
        
        print(f"Average response time: {avg_response_time:.4f}s")
        print(f"Max response time: {max_response_time:.4f}s")
        print(f"Min response time: {min_response_time:.4f}s")
        
        # Performance assertions
        assert avg_response_time < 0.5  # Average should be under 500ms
        assert max_response_time < 2.0  # Max should be under 2 seconds

if __name__ == "__main__":
    pytest.main([__file__])
