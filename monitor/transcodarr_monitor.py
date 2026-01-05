"""
Transcodarr Monitor - Main TUI Application.
A terminal-based monitoring tool for Transcodarr transcoding.
"""

import asyncio
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Header, Footer, Static

from .config import get_config, reload_config
from .data_collector import DataCollector
from .widgets import StatusBar, TranscodePanel, HistoryPanel, LogPanel


class TranscodarrMonitor(App):
    """Main Transcodarr Monitor application."""

    TITLE = "Transcodarr Monitor"
    SUB_TITLE = "Distributed Live Transcoding for Jellyfin"

    CSS = """
    Screen {
        background: $background;
    }

    #main-container {
        width: 100%;
        height: 100%;
        padding: 1;
    }

    #top-section {
        height: auto;
    }

    #middle-section {
        height: 1fr;
    }

    #bottom-section {
        height: 1fr;
        min-height: 10;
    }

    StatusBar {
        margin: 0 0 1 0;
    }

    TranscodePanel {
        margin: 0 0 1 0;
    }

    HistoryPanel {
        margin: 0 0 1 0;
    }

    LogPanel {
        height: 100%;
    }

    #hosts-panel {
        height: auto;
        background: $surface;
        border: solid $primary;
        padding: 0 1;
        margin: 0 0 1 0;
    }

    #hosts-title {
        text-style: bold;
        color: $primary;
    }

    .hidden {
        display: none;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("r", "refresh", "Refresh"),
        Binding("l", "toggle_logs", "Toggle Logs"),
        Binding("c", "reload_config", "Reload Config"),
    ]

    def __init__(self):
        super().__init__()
        self.config = get_config()
        self.collector = DataCollector(self.config)
        self._refresh_task = None
        self._show_logs = True

    def compose(self) -> ComposeResult:
        yield Header()
        with Container(id="main-container"):
            with Vertical(id="top-section"):
                yield StatusBar(id="status-bar")
                yield Static(id="hosts-panel")
            with Vertical(id="middle-section"):
                yield TranscodePanel(id="transcode-panel")
                yield HistoryPanel(id="history-panel")
            with Vertical(id="bottom-section"):
                yield LogPanel(id="log-panel")
        yield Footer()

    async def on_mount(self) -> None:
        """Start the refresh loop when the app mounts."""
        self._update_hosts_panel([])
        await self._do_refresh()
        self._refresh_task = asyncio.create_task(self._refresh_loop())

    async def on_unmount(self) -> None:
        """Stop the refresh loop when the app unmounts."""
        if self._refresh_task:
            self._refresh_task.cancel()
            try:
                await self._refresh_task
            except asyncio.CancelledError:
                pass

    async def _refresh_loop(self) -> None:
        """Background task that refreshes data periodically."""
        while True:
            await asyncio.sleep(self.config.refresh_interval)
            await self._do_refresh()

    async def _do_refresh(self) -> None:
        """Perform a data refresh."""
        try:
            data = await self.collector.collect_all()

            # Update all widgets
            status_bar = self.query_one("#status-bar", StatusBar)
            status_bar.update_status(data.status)

            transcode_panel = self.query_one("#transcode-panel", TranscodePanel)
            transcode_panel.update_jobs(data.active_transcodes)

            history_panel = self.query_one("#history-panel", HistoryPanel)
            history_panel.update_history(data.history)

            log_panel = self.query_one("#log-panel", LogPanel)
            log_panel.update_logs(data.logs)

            self._update_hosts_panel(data.rffmpeg_hosts)

        except Exception as e:
            self.notify(f"Refresh error: {e}", severity="error")

    def _update_hosts_panel(self, hosts: list[dict]) -> None:
        """Update the hosts panel with rffmpeg host info."""
        panel = self.query_one("#hosts-panel", Static)

        if not hosts:
            panel.update("[bold magenta]rffmpeg Hosts[/bold magenta]\n[dim]No hosts registered[/dim]")
            return

        content = "[bold magenta]rffmpeg Hosts[/bold magenta]\n"
        for host in hosts:
            state_color = "green" if host.get("state") == "idle" else "yellow"
            active = host.get("active", "0")
            content += f"  [{state_color}]\u25cf[/{state_color}] {host.get('hostname', 'Unknown')}"
            content += f" (weight: {host.get('weight', '?')}, active: {active})\n"

        panel.update(content.strip())

    def action_quit(self) -> None:
        """Quit the application."""
        self.exit()

    async def action_refresh(self) -> None:
        """Manual refresh."""
        self.notify("Refreshing...", severity="information")
        await self._do_refresh()
        self.notify("Refreshed!", severity="information")

    def action_toggle_logs(self) -> None:
        """Toggle log panel visibility."""
        log_panel = self.query_one("#log-panel", LogPanel)
        self._show_logs = not self._show_logs

        if self._show_logs:
            log_panel.remove_class("hidden")
        else:
            log_panel.add_class("hidden")

    def action_reload_config(self) -> None:
        """Reload configuration from disk."""
        self.config = reload_config()
        self.collector = DataCollector(self.config)
        self.notify("Configuration reloaded", severity="information")


def check_ssh_before_ui(config) -> bool:
    """Test SSH connection before starting UI.

    This allows the user to enter their password in the terminal
    BEFORE Textual takes over the screen.
    """
    import subprocess

    print(f"Connecting to {config.nas_user}@{config.nas_ip}...")

    cmd = config.get_ssh_command("echo ok")

    try:
        # Run with stdin/stdout connected to terminal (allows password input)
        result = subprocess.run(
            cmd,
            timeout=30,
            capture_output=False  # Let password prompt show in terminal
        )

        if result.returncode == 0:
            print("✓ SSH connection successful\n")
            return True
        else:
            print("✗ SSH connection failed")
            return False

    except subprocess.TimeoutExpired:
        print("✗ SSH connection timed out")
        return False
    except Exception as e:
        print(f"✗ SSH error: {e}")
        return False


def main():
    """Entry point for the monitor."""
    import sys

    config = get_config()

    if config.is_synology:
        # Running directly on Synology - no SSH needed
        print("Detected Synology NAS - running in local mode")
        print("✓ Direct access to Jellyfin container\n")
    else:
        # Running on Mac - need SSH to NAS
        # Test SSH BEFORE starting UI so password prompt is visible
        if not check_ssh_before_ui(config):
            print("\nSSH connection required for monitoring.")
            print(f"Make sure you can SSH to: {config.nas_user}@{config.nas_ip}")
            print("\nTip: Set up SSH key authentication to avoid password prompts:")
            print(f"  ssh-copy-id {config.nas_user}@{config.nas_ip}")
            sys.exit(1)

    # Start UI
    app = TranscodarrMonitor()
    app.run()


if __name__ == "__main__":
    main()
