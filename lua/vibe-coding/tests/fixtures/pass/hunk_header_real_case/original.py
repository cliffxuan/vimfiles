def generate_cluster_type_alias():
    """Generate type aliases (SITE, PLATFORM, CLUSTER) and write to primitives.py."""
    console.print("[bold blue]Generating type aliases...[/bold blue]")

    all_clusters = []
    platforms: list[PLATFORM] = ["isilon", "vast"]

    for platform in platforms:
        try:
            clusters = get_clusters(platform)
            all_clusters.extend(clusters)
            console.print(
                f"[blue]Found {len(clusters)} {platform.title()} clusters[/blue]"
            )
        except Exception as e:
            console.print(f"[red]Error fetching {platform.title()} clusters: {e}[/red]")

    if not all_clusters:
        console.print("[red]No clusters found, cannot generate type alias[/red]")
        return

    # Sort clusters for consistent output
    all_clusters.sort()