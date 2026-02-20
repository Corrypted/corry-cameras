# Dependencies
1. [qb-core](https://github.com/qbcore-framework/qb-core)
2. [ox_lib](https://github.com/overextended/ox_lib)
3. [ox_target](https://github.com/overextended/ox_target)
4. [oxmysql](https://github.com/overextended/oxmysql)

# Installation
1. Add files to your server resources.
2. Ensure `corry-cameras` in your server cfg. Make sure ox_lib starts before corry-cameras.
3. Set the config in `config.lua` to your needs.
4. Run the `corry_scripts.sql` into your database.
5. Copy and paste the following code into the bottom of `ox_inventory/data/items.lua`: Here's an example image: https://kappa.lol/h23BaH
    ```	--- Corry Cameras ---
        ["camera"] = {
            label = 'Camera',
            weight = 1000,
            stack = false,
            close = true,
            description = "A camera to totally not spy on people with.",
            consume = 1.0,
            client = {
                image = "camera.png",
            },
        },
        ["camera_tablet"] = {
            label = 'Camera Tablet',
            weight = 2000,
            stack = false,
            close = true,
            description = "A tablet to view your camera feeds on.",
            client = {
                image = "camera_tablet.png",
            },
        },
    ```
6. Copy and paste the following code into the bottom of `ox_inventory/modules/items/client.lua`: Here's an example image: https://kappa.lol/ERTARH
    ```--- corry-cameras ---
    Item('camera', function(data, slot)
        ox_inventory:useItem(data, function(data)
            if data then
                TriggerEvent('camera:client:useCamera')
            end
        end)	
    end)

    Item('camera_tablet', function(data, slot)
        ox_inventory:useItem(data, function(data)
            if data then
                TriggerServerEvent('camera:server:OpenCameraTablet')
            end
        end)	
    end)```
7. Drag and drop the images provided into `ox_inventory/web/images`.
8. If you modify the item name in the config, you need to use the same name in the functions above and the images.

# To do
 - Create logging for each Placed/Destroyed camera.
 - Create an admin view of the camera list allowing camera to be remotely destroyed via the menu.0



For any support needed, join the discord: https://discord.gg/CgUjYhUKQy
