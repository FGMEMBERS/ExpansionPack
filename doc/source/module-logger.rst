.. index:: single: logger

logger
======

The ``logger`` module provides functions to print colored debug messages to the terminal and colored messages to the screen.

Printing text to the terminal
-----------------------------

The following message types can be printed:

* Information

* Warnings

* Errors

For example, the following call:

.. code-block:: javascript

   logger.info("This is an informational message");

will print the following text in bold white:

.. code-block:: sh

   Info: This is an informational message

While:

.. code-block:: javascript

   logger.warn("This is a warning");

will print the following text in bold yellow:

.. code-block:: sh

   Warning: This is a warning

And:

.. code-block:: javascript

   logger.error("This is an error");

will print the following text in bold red:

.. code-block:: sh

   Error: This is an error

Showing colored messages on the screen
--------------------------------------

Messages can be shown on the screen in various colors. The following colors can be used:

* Red

* Green

* Blue

* white

A message can be displayed using ``logger.screen``. For example:

.. code-block:: javascript

   logger.screen.green("Refueling complete!");

will display a green message at the top of the screen saying "Refueling complete!"
