def generate_cluster_type_alias():
    """Generate type aliases (SITE, PLATFORM, CLUSTER) and write to primitives.py."""
    console.print("[bold blue]Generating type aliases...[/bold blue]")

    all_cluster_names = []
    platforms: list[PLATFORM] = ["isilon", "vast"]

    for platform in platforms:
        try:
            clusters = get_clusters(platform)
            all_cluster_names.extend(clusters.keys())
            console.print(
                f"[blue]Found {len(clusters)} {platform.title()} clusters[/blue]"
            )
        except Exception as e:
            console.print(f"[red]Error fetching {platform.title()} clusters: {e}[/red]")

    if not all_cluster_names:
        console.print("[red]No clusters found, cannot generate type alias[/red]")
        return

    # Sort clusters for consistent output
    all_cluster_names.sort()