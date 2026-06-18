# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

from pathlib import Path

from shomer_migrations import __version__
from shomer_migrations.migrate import _config


def test_version_is_string() -> None:
    assert isinstance(__version__, str)


def test_config_points_at_packaged_migrations() -> None:
    # The runner must resolve the revisions shipped inside the wheel.
    location = _config().get_main_option("script_location")
    assert location is not None
    assert (Path(location) / "env.py").is_file()
