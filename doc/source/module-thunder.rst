.. index:: single: thunder
.. _module-thunder:

thunder
=======

The ``thunder`` module enables the thunder sounds provided by ``fgdata``.

Import the module by adding the following to a .nas file:

    .. code-block:: javascript
       :linenos:

        io.include("Aircraft/ExpansionPack/Nasal/init.nas");

        with("thunder");

Adding sounds
-------------

Add the following to your aircraft's sound XML file:

    .. code-block:: xml
       :linenos:

       <thunder1>
           <name>thunder1</name>
           <mode>once</mode>
           <path>Sounds/thunder1.wav</path>
           <property>/sim/sound/thunder1</property>
           <volume>
               <property>/sim/sound/volume-thunder1</property>
           </volume>
       </thunder1>
       <thunder2>
           <name>thunder2</name>
           <mode>once</mode>
           <path>Sounds/thunder2.wav</path>
           <property>/sim/sound/thunder2</property>
           <volume>
               <property>/sim/sound/volume-thunder2</property>
           </volume>
       </thunder2>
       <thunder3>
           <name>thunder3</name>
           <mode>once</mode>
           <path>Sounds/thunder3.wav</path>
           <property>/sim/sound/thunder3</property>
           <volume>
               <property>/sim/sound/volume-thunder3</property>
           </volume>
       </thunder3>

The expansion pack provides a number of ``<filter>``'s for
helping to control the volume of the thunder sounds. First, extend
one of the provided XML files and define the necessary parameters.
For example, in your aircraft's ``System/`` directory, create the file
``thunder.xml``:

    .. code-block:: xml
       :linenos:

       <?xml version="1.0" encoding="UTF-8"?>

       <PropertyList include="Aircraft/ExpansionPack/Systems/thunder-two-windows.xml">

           <params>
               <windows>
                   <left>/sim/multiplay/generic/float[4]</left>
                   <right>/sim/multiplay/generic/float[5]</right>
               </windows>
           </params>

       </PropertyList>

Adjust the parameters so that the correct multiplayer properties are used
for your aircraft. Second, import the file in your ``-set.xml`` file. For
example:

    .. code-block:: xml
       :linenos:

        <autopilot>
            <path>Aircraft/707/Systems/thunder.xml</path>
        </autopilot>

Now you should be able to hear the thunder a couple of seconds after you
see any lightning. The delay depends on the distance of the thunderstorm
and the temperature and relative humidity of the atmosphere. The volume
depends on the view (external or in the cockpit) and whether you have
opened or closed one or both of the windows.
