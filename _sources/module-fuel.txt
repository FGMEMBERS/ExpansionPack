.. index:: single: fuel
.. _module-fuel:

fuel
====

The ``fuel`` module defines several components that you can use to create
a fuel system. By creating instances of the components and connecting them,
you can build a graph. However, you must make sure that the graph contains
no cycles. Fuel will always flow in one way through the nodes of the system,
and if the system contains no cycles, the fuel system is essentially a
`directed acyclic graph`_.

.. caution::
   Do not create cycles in the fuel system graph by connecting components
   in the wrong order. Doing so will result in Nasal runtime errors.

All components are visible in the property tree under ``/systems/fuel``.

.. tip::
   Set ``/systems/fuel/debug`` to true in order to see which pumps are
   pumping fuel and how much.

**Current fuel flow rate**

Each component has a ``current-flow-gal_us-ps`` property which denotes
the flow in US gallons per second flowing through the component. To keep
this property up-to-date, the component must be added to a certain data
structure. How this is done is explained later.

**Failable components**

Components which ought to have ingoing *and* outgoing connections have two
additional properties which control the normalized flow rate. One of these
properties is only written to by the fuel system, the other is only read
from. An `XML property rule`_ should be used to connect these two properties.
The idea is that you can use the `FailureMgr`_ to control the actual normalized
flow rate.

**Serviceable components**

Some components like the ``BoostPump`` and the ``Valve`` are serviceable.
This means that you can directly control whether they are enabled or disabled.
You can also let a pilot control whether a serviceable component is *selected*.
For example, you can let the pilot decide whether a component is selected, but
use automatic logic to make the component serviceable or not. If and only
if a component is serviceable *and* selected, it is enabled. Otherwise the
component will be disabled. This is useful for boost pumps, which you may
want to control automatically if they are selected by the pilot.

**Persistant tank levels**

The ``fuel`` module provides a function that you can call to make the tank
levels persistant. This means that if the user properly shuts down FlightGear,
then the current tank levels will be saved, and the next session will start
with the same tank levels.

To make the tank levels persistant, call the following function after
having constructed the fuel system:

    .. code-block:: javascript
       :linenos:

        fuel.make_tank_levels_persistent()

Components
----------

All fuel components are a subclass of the ``FuelComponent`` class. The
hierarchy is as follows:

* ``FuelComponent``

    + ``TransferableFuelComponent``

        * ``ActiveFuelComponent``

            + ``AbstractPump``

                - ``BoostPump`` (implements ``ServiceableFuelComponentMixin``)

                - ``AutoPump``

                - ``GravityPump``

        * ``Valve`` (implements ``ServiceableFuelComponentMixin``)

        * ``Tube``

    + ``Tank``

        * ``LeakableTank``

    + ``Manifold``

    + ``AbstractConsumer``

        * ``EngineConsumer``

        * ``JettisonConsumer``

    + ``AbstractProducer``

        * ``AirRefuelProducer``

        * ``GroundRefuelProducer``

TransferableFuelComponent
^^^^^^^^^^^^^^^^^^^^^^^^^

Components that are a subclass of the ``TransferableFuelComponent`` class
will have ingoing *and* outgoing connections and have two additional
properties that determine the actual flow rate through the component.

1. ``requested-flow-factor``

2. ``actual-flow-factor``

The fuel sytem will write to the first property the normalized flow rate
that it requests and reads the actual normalized flow rate from the second
property. The fuel system will only work if the aircraft has defined an
`XML property rule`_ to connect these two properties. This way you can use
`FailureMgr`_ to control the ``actual-flow-factor`` property.

.. important::
   Without an XML property rule, no fuel will actually flow through an
   instance of a ``TransferableFuelComponent``. Even if you do not plan to
   use the ``FailureMgr``, you must add an XML property rule.

   Pumps, tubes, and valves all require an XML property rule. For valves
   and pumps it is recommended to use a `noise-spike`_ filter.

ServiceableFuelComponentMixin
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Components that implement the ``ServiceableFuelComponentMixin`` mixin provide
two properties that can be used to enable or disable the component:

1. ``serviceable``

2. ``selected``

The first property is false and the second property is true by default. If both
properties are true then the component will be enabled, otherwise it will be
disabled.

If you want a pilot to directly control a component, you should allow the
pilot to toggle the ``serviceable`` property; via a switch in the cockpit,
for example. For components that are controlled by some automatic logic,
you should use the ``selected`` property instead.

Network
-------

TODO

.. _directed acyclic graph: https://en.wikipedia.org/wiki/Directed_acyclic_graph
.. _XML property rule: http://wiki.flightgear.org/Autopilot_configuration_reference
.. _FailureMgr: http://wiki.flightgear.org/A_Failure_Management_Framework_for_FlightGear
.. _noise-spike: http://wiki.flightgear.org/Autopilot_configuration_reference#Rate_limit_filter_.3Cnoise-spike.3E
