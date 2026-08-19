# JupyterHub configuration for stdin support
# Enable stdin support in spawned single-user servers
c.Spawner.args = [
    '--KernelManager.allow_stdin=True',
]

# Additional kernel manager configuration
c.JupyterHub.spawner_class = 'jupyterhub.spawners.SimpleLocalProcessSpawner'
