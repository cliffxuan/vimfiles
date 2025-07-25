@patch("app.utils.share.get_clusters")
def test_get_platform_shares_success(mock_get_clusters, mock_get_cluster_shares):
    """Test successful retrieval of platform shares."""
    from app.utils.share import get_platform_shares

    # Mock clusters data
    mock_get_clusters.return_value = {
        "cluster1": {"name": "cluster1", "platform": "vast", "state": "LIVE"},
        "cluster2": {"name": "cluster2", "platform": "vast", "state": "LIVE"},
    }

    # Mock shares data for each cluster
    mock_get_cluster_shares.side_effect = [
        [{"share": "share1", "path": "/path1"}, {"share": "share2", "path": "/path2"}],
        [{"share": "share3", "path": "/path3"}],
    ]

    result = get_platform_shares("vast")


@patch("app.utils.share.get_cluster_shares")
@patch("app.utils.share.get_clusters")
def test_get_platform_shares_with_cluster_error(
    mock_get_clusters, mock_get_cluster_shares, mock_logger
):
    """Test get_platform_shares when one cluster fails but others succeed."""
    from app.utils.share import get_platform_shares

    # Mock clusters data
    mock_get_clusters.return_value = {
        "cluster1": {"name": "cluster1", "platform": "isilon", "state": "LIVE"},
        "cluster2": {"name": "cluster2", "platform": "isilon", "state": "LIVE"},
        "cluster3": {"name": "cluster3", "platform": "isilon", "state": "LIVE"},
    }

    # Mock shares data - cluster2 will fail, others succeed
    mock_get_cluster_shares.side_effect = [
        [{"share": "share1", "path": "/path1"}],  # cluster1 success
        Exception("Connection timeout"),  # cluster2 fails
        [{"share": "share3", "path": "/path3"}],  # cluster3 success
    ]