// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { SecurityCouncil_Initializer } from "./CommonTest.t.sol";
import { Types } from "../libraries/Types.sol";

contract SecurityCouncilTest is SecurityCouncil_Initializer {
    /**
     *  Events
     */
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Revocation(address indexed sender, uint256 indexed transactionId);
    event Submission(uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);
    event ValidationRequested(
        uint256 indexed transactionId,
        bytes32 outputRoot,
        uint256 l2BlockNumber
    );
    event DeletionRequested(uint256 indexed transactionId, uint256 indexed outputIndex);

    function test_initialize_succeeds() external {
        address[] memory _owners = securityCouncil.getOwners();
        for (uint256 i = 0; i < _owners.length; i++) {
            assertEq(securityCouncil.owners(i), _owners[i]);
        }

        assertEq(securityCouncil.COLOSSEUM(), colosseumAddr);
        assertEq(securityCouncil.GOVERNOR(), upgradeGovernor);
        assertEq(securityCouncil.numConfirmationsRequired(), NUM_CONFIRMATIONS_REQUIRED);
        assertEq(securityCouncil.getTransactionCount(true, true), 0);
    }

    function test_submitTransaction_reverts() external {
        vm.prank(makeAddr("not owner"));
        vm.expectRevert("MultiSigWallet: owner does not exist");
        securityCouncil.submitTransaction(owners[0], 0, bytes("anydata"));
    }

    function test_submitTransaction_succeeds() external {
        // submit dummy transaction
        vm.prank(address(owners[0]));
        vm.expectEmit(true, false, false, false);
        emit Submission(0);
        uint256 txId = securityCouncil.submitTransaction(owners[0], 0, bytes("anydata"));

        // check transaction count increased
        Types.MultiSigTransaction memory t;
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.destination, owners[0]);
        assertEq(t.executed, false);
        assertEq(t.value, 0);
        assertEq(t.data, bytes("anydata"));

        uint256 txCount = securityCouncil.transactionCount();
        assertEq(txCount, 1);
    }

    function test_confirmTransaction_reverts() external {
        // submit dummy transaction
        vm.prank(address(owners[0]));
        uint256 txId = securityCouncil.submitTransaction(owners[0], 0, bytes("anydata"));

        // check revert confirm transaction
        vm.expectRevert();
        vm.prank(makeAddr("not owner"));
        securityCouncil.confirmTransaction(txId);
    }

    function test_confirmTransaction_succeeds() external {
        // submit dummy transaction
        vm.prank(address(owners[0]));
        uint256 txId = securityCouncil.submitTransaction(owners[0], 0, bytes("anydata"));

        // check transaction confirmed
        address[] memory confirmList;
        confirmList = securityCouncil.getConfirmations(txId);
        assertEq(confirmList.length, 1);

        // check transaction not executed
        Types.MultiSigTransaction memory t;
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, false);

        // confirm transaction
        vm.expectEmit(true, false, false, false);
        emit Confirmation(owners[1], txId);
        vm.prank(owners[1]);
        securityCouncil.confirmTransaction(txId);

        // check transaction confirmed
        confirmList = securityCouncil.getConfirmations(txId);
        assertEq(confirmList.length, 2);

        // check transaction executed
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, true);
    }

    function test_revokeConfirmation_succeeds() external {
        // submit dummy transaction
        vm.prank(address(owners[0]));
        uint256 txId = securityCouncil.submitTransaction(owners[0], 0, bytes("anydata"));

        // revoke confirmation
        vm.expectEmit(true, false, false, false);
        emit Revocation(owners[0], txId);
        vm.prank(owners[0]);
        securityCouncil.revokeConfirmation(txId);

        // check confirmation revoked
        address[] memory confirmList;
        confirmList = securityCouncil.getConfirmations(txId);
        assertEq(confirmList.length, 0);
    }

    function test_executeTransaction_succeeds() external {
        // submit dummy transaction
        vm.prank(address(owners[0]));
        uint256 txId = securityCouncil.submitTransaction(owners[0], 0, bytes("anydata"));

        // confirm transaction to execute
        vm.prank(owners[1]);
        securityCouncil.confirmTransaction(txId);

        // check transaction count increased
        Types.MultiSigTransaction memory t;
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, true);
    }

    function test_requestValidation_reverts() external {
        vm.prank(makeAddr("not colosseum"));
        vm.expectRevert("SecurityCouncil: only the colosseum contract can be a sender");
        securityCouncil.requestValidation(bytes32(0), 0, bytes("anydata"));
    }

    function test_requestValidation_succeeds() external {
        // request output validation
        bytes32 outputRoot = bytes32("dummy output root");
        uint128 l2BlockNumber = 3;
        vm.prank(colosseumAddr);
        vm.expectEmit(true, false, false, false);
        emit ValidationRequested(0, outputRoot, l2BlockNumber);
        securityCouncil.requestValidation(outputRoot, l2BlockNumber, bytes("anydata"));
    }

    function test_executeValidateTransaction_succeeds() external {
        // request output validation
        bytes32 outputRoot = bytes32("dummy output root");
        uint128 l2BlockNumber = 3;
        uint256 txId = 0;
        vm.prank(colosseumAddr);
        vm.expectEmit(true, false, false, false);
        emit ValidationRequested(txId, outputRoot, l2BlockNumber);
        securityCouncil.requestValidation(outputRoot, l2BlockNumber, bytes("anydata"));

        // check transaction not executed
        Types.MultiSigTransaction memory t;
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, false);

        // confirm transaction to execute
        vm.prank(owners[0]);
        securityCouncil.confirmTransaction(txId);
        vm.prank(owners[1]);
        securityCouncil.confirmTransaction(txId);

        // check transaction confirmed
        address[] memory confirmList;
        confirmList = securityCouncil.getConfirmations(txId);
        assertEq(confirmList.length, 2);

        // check transaction executed
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, true);
    }

    function test_requestDeletion_succeeds() external {
        // request output deletion
        uint256 _outputIndex = 1;
        uint256 txId = 0;
        vm.prank(owners[0]);
        vm.expectEmit(true, true, false, false);
        emit DeletionRequested(txId, _outputIndex);
        securityCouncil.requestDeletion(_outputIndex, false);

        // check transaction not executed
        Types.MultiSigTransaction memory t;
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, false);

        // confirm transaction to execute
        vm.prank(owners[1]);
        securityCouncil.confirmTransaction(txId);

        // check transaction confirmed
        address[] memory confirmList;
        confirmList = securityCouncil.getConfirmations(txId);
        assertEq(confirmList.length, 2);

        // check transaction executed
        (t.destination, t.executed, t.value, t.data) = securityCouncil.transactions(txId);
        assertEq(t.executed, true);
    }

    function test_requestDeletion_alreadyRequested_reverts() external {
        // request output deletion
        uint256 _outputIndex = 1;
        vm.prank(owners[0]);
        vm.expectEmit(true, true, false, false);
        emit DeletionRequested(0, _outputIndex);
        securityCouncil.requestDeletion(_outputIndex, false);

        // try to request the same output index
        vm.prank(owners[0]);
        vm.expectRevert("SecurityCouncil: the output has already been requested to be deleted");
        securityCouncil.requestDeletion(_outputIndex, false);
    }

    function test_requestDeletion_force_succeeds() external {
        // request output deletion
        uint256 _outputIndex = 1;
        vm.prank(owners[0]);
        vm.expectEmit(true, true, false, false);
        emit DeletionRequested(0, _outputIndex);
        securityCouncil.requestDeletion(_outputIndex, false);

        // try to request the same output index
        vm.prank(owners[0]);
        vm.expectEmit(true, true, false, false);
        emit DeletionRequested(1, _outputIndex);
        securityCouncil.requestDeletion(_outputIndex, true);
    }
}
