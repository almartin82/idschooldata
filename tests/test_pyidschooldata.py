"""
Tests for pyidschooldata Python wrapper.

Minimal smoke tests - the actual data logic is tested by R testthat.
These just verify the Python wrapper imports and exposes expected functions.
"""

import pytest


def test_import_package():
    """Package imports successfully."""
    import pyidschooldata
    assert pyidschooldata is not None


def test_has_fetch_enr():
    """fetch_enr function is available."""
    import pyidschooldata
    assert hasattr(pyidschooldata, 'fetch_enr')
    assert callable(pyidschooldata.fetch_enr)


def test_has_get_available_years():
    """get_available_years function is available."""
    import pyidschooldata
    assert hasattr(pyidschooldata, 'get_available_years')
    assert callable(pyidschooldata.get_available_years)


def test_has_version():
    """Package has a version string."""
    import pyidschooldata
    assert hasattr(pyidschooldata, '__version__')
    assert isinstance(pyidschooldata.__version__, str)
