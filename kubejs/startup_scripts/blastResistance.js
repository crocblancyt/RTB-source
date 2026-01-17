const blockResistances = {
  minecraft: {
    stone: 30,
    dirt: 25,
    coarse_dirt: 8,
    grass_block: 8,
    farmland: 8,
    sand: 8,
  },
  create: {
    redstone_link: 20,
    analog_lever: 20,
    red_seat: 16,
    white_seat: 16,
    orange_seat: 16,
    magenta_seat: 16,
    light_blue_seat: 16,
    yellow_seat: 16,
    lime_seat: 16,
    pink_seat: 16,
    gray_seat: 16,
    light_gray_seat: 16,
    cyan_seat: 16,
    purple_seat: 16,
    blue_seat: 16,
    brown_seat: 16,
    green_seat: 16,
    black_seat: 16,
  },
  vs_clockwork: {
    phys_bearing: 20,
    command_seat: 16,
  },
  createbigcannons:{
    cannon_mount: 20,
  },
  cbcmodernwarfare:{
    compact_mount: 20,
  },
  tallyho:{
    ripple_block: 20,
    scope_block: 16,
  }
};

BlockEvents.modification(event => {
  for (let mod in blockResistances) {
    for (let blockName in blockResistances[mod]) {
      // Declare fullId directly without let/const
      event.modify(`${mod}:${blockName}`, block => {
        block.explosionResistance = blockResistances[mod][blockName];
      });
    }
  }
});

