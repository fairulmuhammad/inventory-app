import pytest
import time
import requests
import concurrent.futures
from threading import Thread
import statistics

class TestPerformance:
    """Performance tests for the inventory service"""
    
    BASE_URL = "http://localhost:5000"
    
    def test_response_time_get_items(self):
        """Test response time for getting all items"""
        start_time = time.time()
        response = requests.get(f"{self.BASE_URL}/items")
        end_time = time.time()
        
        response_time = end_time - start_time
        assert response.status_code == 200
        assert response_time < 1.0  # Should respond within 1 second
        
    def test_concurrent_requests(self):
        """Test handling concurrent requests"""
        def make_request():
            return requests.get(f"{self.BASE_URL}/items")
        
        # Test with 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        for response in results:
            assert response.status_code == 200
            
    def test_load_test_simple(self):
        """Simple load test"""
        response_times = []
        
        for i in range(50):
            start_time = time.time()
            response = requests.get(f"{self.BASE_URL}/items")
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
