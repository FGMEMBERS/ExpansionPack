Fuel Truck Dialog
=================

The `fuel_truck_dialog` module provides a 3D model of a fuel truck and a dialog to control the visibility of the truck and the fuel line. The dialog also provides a button to start and stop the refueling. Furthermore, the expansion pack provides a `.wav` file and a `<filter>` to help control the volume of the fuel truck.

Adding the 3D model and dialog
------------------------------

1. Import the fuel_truck_model by adding the following to a `.nas` file:

    ```javascript
    io.include("Aircraft/ExpansionPack/Nasal/init.nas");

    with("fuel_truck_dialog");
    ```

2. Add an `<item>` to your aircraft's `<menu>`:

   ```xml
    <item>
        <label>-- Ground Services --</label>
        <enabled type="bool">false</enabled>
    </item>

    <item>
        <label>Fuel Truck</label>
        <binding>
            <command>dialog-show</command>
            <dialog-name>fuel-truck</dialog-name>
        </binding>
    </item>
    ```

3. Add the fuel truck 3D model to your aircraft's model XML file:

    ```xml
    <model>
        <name>fuel-truck</name>
        <path>Aircraft/ExpansionPack/Models/Airport/Fuel-Truck/fuel-truck.xml</path>
        <offsets>
            <x-m>0.0</x-m>
            <y-m>0.0</y-m>
            <z-m>0.0</z-m>
        </offsets>
    </model>

    <animation>
        <type>select</type>
        <object-name>fuel-truck</object-name>
        <condition>
            <property>/sim/model/fuel-truck/enabled</property>
        </condition>
    </animation>
    ```

Adding sounds
-------------

1. The expansion pack provides a `pushback.wav` and a `<filter>` for helping to control the volume of the fuel truck. First, import the `<filter>` to your `-set.xml` file:

    ```xml
    <autopilot>
        <path>Aircraft/ExpansionPack/Systems/fuel-truck.xml</path>
    </autopilot>
    ```

2. Then create a file called `Systems/sound-fuel-truck.xml` and add it to your aircraft. In this file you need to add a gain `<filter>` that uses the `/sim/model/fuel-truck/state` property as the gain and outputs the volume to another property, for example `/sim/model/fuel-truck/volume`. This is what the Osprey uses:

    ```xml
    <filter>
        <update-interval-secs type="double">0.1</update-interval-secs>
        <type>gain</type>
        <gain>
            <property>/sim/model/fuel-truck/state</property>
        </gain>
        <input>
            <condition>
                <property>/sim/current-view/internal</property>
            </condition>
            <value>0.2</value>
            <offset>
                <expression>
                    <product>
                        <!-- Boost the volume if both cockpit and starboard doors are open -->
                        <property>/instrumentation/doors/cockpitdoor/position-norm</property>
                        <property>/instrumentation/doors/crewup/position-norm</property>
                        <value>0.4</value>
                    </product>
                </expression>
            </offset>
        </input>
        <input>
            <value>1.0</value>
        </input>
        <output>
            <property>/sim/model/fuel-truck/volume</property>
        </output>
    </filter>
    ```

3. Add the `sound-fuel-truck.xml` file to your `-set.xml` file:

    ```xml
    <autopilot>
        <path>Systems/sound-fuel-truck.xml</path>
    </autopilot>
    ```

4. Finally, you need to use the `/sim/model/fuel-truck/volume` property to control the volume of the `pushback.wav` file. Add the following to your aircraft's sound XML file. This is what the Osprey uses:

    ```xml
    <fuel-truck-outside>
        <name>fuel-truck-outside</name>
        <mode>looped</mode>
        <path>Aircraft/ExpansionPack/Sounds/pushback.wav</path>
        <condition>
            <property>/sim/model/fuel-truck/enabled</property>
        </condition>
        <volume>
            <property>/sim/model/fuel-truck/volume</property>
            <factor>1.0</factor>
            <offset>0.0</offset>
            <min>0.1</min>
            <max>7.0</max>
        </volume>
        <pitch>
            <property>/sim/model/fuel-truck/state</property>
            <factor>0.3</factor>
            <offset>1.1</offset>
        </pitch>
    </fuel-truck-outside>
    ```

Initial Position
----------------

The initial position of the fuel truck can be set in the aircraft's `-set.xml` file:

```xml
<systems>
    <refuel-ground>
        <x-m type="double">-8.0</x-m>
        <y-m type="double">-15.0</y-m>
        <yaw-deg type="double">300.0</yaw-deg>
    </refuel-ground>
</systems>
```

Properties
----------

The Fuel Truck dialog depends on several properties in `/systems/refuel-ground/` and `/sim/model/fuel-truck/`. It is recommended to use the dialog in conjunction with a `GroundRefuelProducer` component from the `fuel` module.

* `/systems/refuel-ground/level-gal_us` is the current amount of gallons in the fuel truck.

* `/systems/refuel-ground/refuel` is true if the fuel system should extract fuel out of the fuel truck.

* `/systems/fuel/producer-ground-refuel-fuel-truck/current-flow` indicates the fuel flow in gallons. A value greater than zero indicates the aircraft is actually being refueled. This is shown in the 3D model of the fuel truck by the orange light on top of the fuel truck.
