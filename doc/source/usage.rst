Usage
=====

Importing a module
------------------

To use a module, first load the expansion pack's init.nas file and then call ``with()``:

.. code-block:: javascript

    io.include("Aircraft/ExpansionPack/Nasal/init.nas");

    with("logger");

``with()`` can accept a variable number of arguments, but it is recommended to import one module at a time. Each module name must be lower case and consist of the characters 'a' to 'z' or an underscore (``_``) only. After importing, the module is available via a variable that is named after the module's name:

.. code-block:: javascript

    logger.info("Hello world!");

Including init.nas also makes the ``io.import()`` function available. You can use it to import any .nas file you want and make it available via a variable:

.. code-block:: javascript

    io.import("path/to/my/file.nas", "foobar");

Checking the version of a module
--------------------------------

Each module has a version consisting of a major and a minor number. The major number is incremented when a new version is no longer backward compatible. The minor number is incremented when new features have been added or if bugs have been fixed, but the new version is still backward compatible. If the major number of a module is incremented, the minor number should be set back to 0.

The version of the module can be checked with ``check_version()``:

.. code-block:: javascript

    check_version("fuel", 1, 0);

The major number must be equal and the minor number must greater than or equal.
