def test_function(mock_clusters):
    """Test function docstring."""
    from app.utils.share import get_function

    # Mock clusters data
    mock_get_clusters.return_value = {
        "cluster1": {"name": "cluster1", "platform": "vast"},
        "cluster2": {"name": "cluster2", "platform": "vast"},
    }

    # Mock shares data
    assert True