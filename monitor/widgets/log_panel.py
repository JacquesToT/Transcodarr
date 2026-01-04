"""Panel showing rffmpeg logs."""

from textual.app import ComposeResult
from textual.widgets import Static, RichLog
from textual.containers import VerticalScroll


class LogPanel(Static):
    """Widget showing rffmpeg log output."""

    DEFAULT_CSS = """
    LogPanel {
        height: 1fr;
        background: $surface;
        border: solid $primary;
        padding: 0 1;
    }

    LogPanel #log-title {
        text-style: bold;
        color: $primary;
        padding: 0 0 1 0;
    }

    LogPanel #log-content {
        height: 1fr;
        background: $background;
        scrollbar-gutter: stable;
    }

    LogPanel .log-line {
        color: $text-muted;
    }

    LogPanel .log-error {
        color: $error;
    }

    LogPanel .log-success {
        color: $success;
    }
    """

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self._logs: list[str] = []

    def compose(self) -> ComposeResult:
        yield Static("Logs (rffmpeg)", id="log-title")
        yield RichLog(id="log-content", highlight=True, markup=True)

    def update_logs(self, logs: list[str]) -> None:
        """Update the log display."""
        log_widget = self.query_one("#log-content", RichLog)

        # Only add new logs
        new_logs = logs[len(self._logs):]
        self._logs = logs

        for line in new_logs:
            styled_line = self._style_log_line(line)
            log_widget.write(styled_line)

    def clear_logs(self) -> None:
        """Clear the log display."""
        self._logs = []
        log_widget = self.query_one("#log-content", RichLog)
        log_widget.clear()

    def _style_log_line(self, line: str) -> str:
        """Apply styling to a log line based on content."""
        lower = line.lower()

        if "error" in lower or "failed" in lower:
            return f"[red]{line}[/red]"
        elif "success" in lower or "completed" in lower:
            return f"[green]{line}[/green]"
        elif "warning" in lower:
            return f"[yellow]{line}[/yellow]"
        elif "ssh" in lower or "connecting" in lower:
            return f"[cyan]{line}[/cyan]"
        else:
            return f"[dim]{line}[/dim]"
