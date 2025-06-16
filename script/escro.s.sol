// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
 
import {console} from "../lib/forge-std/src/Test.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {Escro} from "../src/escro.sol";
 
contract EscroScript is Script {
    Escro public escro;
 
    function setUp() public {}
 
    function run() public {
        vm.startBroadcast();
 
        escro = new Escro();
 
        vm.stopBroadcast();
    }
}