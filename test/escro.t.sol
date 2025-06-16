// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, stdError} from "../lib/forge-std/src/Test.sol";
import {Escro} from "../src/escro.sol";
import {Receiver} from "./Receiver.sol";

contract EscroTest is Test {
    Escro public escro;
    Receiver seller = new Receiver();
    Receiver buyer = new Receiver();

    function setUp() public {
        escro = new Escro();
        vm.deal(address(seller), 100000000 ether);
        vm.deal(address(buyer), 100 ether);
    }

    function testCreateManyProduct() public {
        for (uint i=0; i<6999; i++) {
            uint cost = i + 100;
            vm.prank(address(seller));
            uint pid = escro.create_new_product{value: 10 ether} ("bike", cost);
            assert(pid == i);
        }
    }

    function testCreateProduct() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);
        console.log(pid1);
        assert(pid1 == 0);

        vm.prank(address(seller));
        uint pid2 = escro.create_new_product{value: 1 ether} ("car", 2000);
        console.log(pid2);
        assert(pid2 == 1);
    }

    function testCreateProductFailed() public {
        vm.prank(address(seller));
        vm.expectRevert("Not enough Deposit for creating new product.");
        escro.create_new_product{value: 250 gwei} ("bike", 1000);
    }

    function testProceedProductSuccessful() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(buyer));
        escro.proceed_product_state(pid1);
    }

    function testProceedProductSuccessful_And_CanceledFailed() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(buyer));
        escro.proceed_product_state(pid1);

        vm.prank(address(buyer));
        vm.expectRevert("Cannot cancel at this state.");
        escro.cancel_product(pid1);
    }

    function testProceedProduct_And_MannerFailed() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(buyer));
        escro.proceed_product_state(pid1);

        vm.prank(address(seller));
        uint pid2 = escro.create_new_product{value: 1 ether} ("car", 1000);

        vm.prank(address(buyer));
        vm.expectRevert("Not enough Deposit for proceeding.");
        escro.proceed_product_state{value: 1240 gwei}(pid2);
    }

    function testProceedProduct_TimeLock() public {

        vm.warp(block.timestamp);
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(seller));
        vm.expectRevert("Cannot finish this trade.");
        escro.proceed_product_state(pid1);

        vm.warp(block.timestamp + 6 days + 30 minutes);
        console.log(block.timestamp);
        
        vm.prank(address(seller));
        vm.expectRevert("Cannot finish this trade.");
        escro.proceed_product_state(pid1);

        // block.timestamp가 vm.wrap을 반영한 듯?
        vm.warp(block.timestamp + 1 days + 30 minutes);
        console.log(block.timestamp);
        vm.prank(address(seller));
        escro.proceed_product_state(pid1);
    }

    function testProceedProduct_And_FailCheck() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(seller));
        vm.expectRevert("Buyer and seller is same.");
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(buyer));
        vm.expectRevert("Cannot ship this trade.");
        escro.proceed_product_state(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(seller));
        vm.expectRevert("Cannot finish this trade.");
        escro.proceed_product_state(pid1);

        vm.prank(address(buyer));
        escro.proceed_product_state(pid1);
    }

    function testCancelProduct_pending() public {
        vm.prank(address(seller));
        uint before = address(seller).balance;
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);
        
        vm.prank(address(seller));
        escro.cancel_product(pid1);
        uint afters = address(seller).balance;
        assert(before == afters);
    }

    function testCancelProduct_pending_failed() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);
        vm.prank(address(buyer));
        vm.expectRevert("Cannot cancel the pending product.");
        escro.cancel_product(pid1);
    }

    function testCancelProduct_proceeding() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        uint before = address(buyer).balance;
        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(buyer));
        escro.cancel_product(pid1);
        uint afters = address(buyer).balance;
        console.log(before, afters);
        assert(before == afters);
    }

    function testCancelProduct_proceeding_fail() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);
        vm.prank(address(seller));
        vm.expectRevert("Cannot cancel the proceeding product.");
        escro.cancel_product(pid1);
    }

    function testCancelProduct_shipping() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(buyer));
        uint beforeBuyer = address(buyer).balance;
        uint beforeSeller = address(seller).balance;
        escro.cancel_product(pid1);
        uint afterBuyer = address(buyer).balance;
        uint afterSeller = address(seller).balance;
        console.log(beforeBuyer, afterBuyer);
        assertEq(beforeSeller, afterSeller);
        console.log(beforeSeller, afterSeller);
        assertEq(beforeSeller, afterSeller);
    }

        function testCancelProduct_shipping_fail() public {
        vm.prank(address(seller));
        uint pid1 = escro.create_new_product{value: 1 ether} ("bike", 1000);

        vm.prank(address(buyer));
        escro.proceed_product_state{value: 1300 gwei}(pid1);

        vm.prank(address(seller));
        escro.proceed_product_state(pid1);

        vm.prank(address(seller));
        vm.expectRevert("Cannot cancel the shipping product.");
        escro.cancel_product(pid1);
    }

}
