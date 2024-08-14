import unittest
from unittest.mock import patch, MagicMock
from service_monitor import lambda_handler, check_active_services

class TestServiceMonitor(unittest.TestCase):
    @patch('service_monitor.check_active_services')
    @patch('service_monitor.send_notification')
    def test_lambda_handler(self, mock_send_notification, mock_check_active_services):
        mock_check_active_services.return_value = {'us-east-1': ['EC2', 'RDS']}
        event = {}
        context = {}
        response = lambda_handler(event, context)
        self.assertEqual(response['statusCode'], 200)
        mock_send_notification.assert_called_once()
    
    @patch('boto3.client')
    def test_check_active_services(self, mock_boto3_client):
        mock_ec2 = MagicMock()
        mock_ec2.describe_regions.return_value = {'Regions': [{'RegionName': 'us-east-1'}]}
        mock_ec2.describe_instances.return_value = {'Reservations': [{}]}
        
        mock_rds = MagicMock()
        mock_rds.describe_db_instances.return_value = {'DBInstances': [{}]}
        
        mock_boto3_client.side_effect = [mock_ec2, mock_ec2, mock_rds]
        
        services = check_active_services()
        self.assertIsInstance(services, dict)
        self.assertEqual(services, {'us-east-1': ['EC2', 'RDS']})

if __name__ == '__main__':
    unittest.main()