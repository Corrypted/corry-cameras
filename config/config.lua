config = {}

config.debug = false

config.cameraItem = {
    itemName = 'camera',
    tabletName = 'camera_tablet',
}

config.tablet = {
    useTablet = true, -- If set to false, will utilize command instead
    tabletItemName = 'camera_tablet',
}

config.animations = {
    place = {
        dict = 'mini@repair',
        anim = 'fixing_a_ped',
        duration = 5000,
        label = 'Placing Camera...',
    },
    destroy = {
        dict = 'mini@repair',
        anim = 'fixing_a_ped',
        duration = 5000,
        label = 'Destroying Camera...',
    },
}