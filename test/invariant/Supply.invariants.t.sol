// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "lib/forge-std/src/Test.sol";
import "./LxLyHandler.sol";

contract Supply is Test {
    LxLyHandler private _handler;

    function setUp() public {
        // create and init the handler
        _handler = new LxLyHandler();
        vm.makePersistent(address(_handler));
        _handler.setUp();
        address handlerAddr = address(_handler);

        // register the actors
        targetSender(_handler.actors(0));
        targetSender(_handler.actors(1));
        targetSender(_handler.actors(2));
        targetSender(_handler.actors(3));
        targetSender(_handler.actors(4));
        targetSender(_handler.actors(5));
        targetSender(_handler.actors(6));

        // register the selectors
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = _handler.deposit.selector;
        selectors[1] = _handler.withdraw.selector;
        selectors[2] = _handler.convert.selector;
        selectors[3] = _handler.migrate.selector;
        targetSelector(FuzzSelector({addr: handlerAddr, selectors: selectors}));

        // register the contract
        targetContract(handlerAddr);
    }

    function invariantTest() public {
        // we don't need to do anything here, just to have it declared
        // the invariant checks are done in the handler
        // declaring this function makes sure the invariant testing is run
    }
}
