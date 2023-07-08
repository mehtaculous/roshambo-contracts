// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import "src/Renderer.sol";
import "src/Roshambo.sol";

contract Deploy is Script {
    Renderer renderer;
    Roshambo roshambo;

    function run() public {
        vm.startBroadcast();
        deploy();
        vm.stopBroadcast();
    }

    function deploy() public {
        renderer = new Renderer();
        roshambo = new Roshambo(renderer, msg.sender);
    }
}
