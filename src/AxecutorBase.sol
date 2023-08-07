// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';
import { AddressToString } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol';

contract AxecutorBase is AxelarExecutable {
    using AddressToString for address;

    string public chain;
    IAxelarGasService public immutable gasService;

    struct Call {
        string chain;
        address target;
        bytes callData;
        bytes[] subCalls;
        address axecutor;
        uint fee;
    }

    constructor(address gateway_, address gasReceiver_, string memory chain_) AxelarExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_);
        chain = chain_;
    }

    function aggregate(bytes[] memory encodedCalls) external payable {
        _processCallsWithGasService(encodedCalls);
    }

    function _aggregate(bytes[] memory encodedCalls) internal {
        _processCallsWithoutGasService(encodedCalls);
    }

    function _processCallsWithGasService(bytes[] memory encodedCalls) private {
        uint256 length = encodedCalls.length;

        for (uint256 i = 0; i < length; i++) {
            Call memory call = abi.decode(encodedCalls[i], (Call));

            if (keccak256(bytes(call.chain)) == keccak256(bytes(chain))) {
                (bool success, ) = call.target.call(call.callData);
                require(success, 'AxecutorBase: call failed');
                _processCallsWithGasService(call.subCalls);
            } else {
                gasService.payNativeGasForContractCall{ value: call.fee }(
                    address(this),
                    call.chain,
                    call.axecutor.toString(),
                    encodedCalls[i],
                    msg.sender
                );
                gateway.callContract(call.chain, call.axecutor.toString(), encodedCalls[i]);
            }
        }
    }

    function _processCallsWithoutGasService(bytes[] memory encodedCalls) private {
        uint256 length = encodedCalls.length;

        for (uint256 i = 0; i < length; i++) {
            Call memory call = abi.decode(encodedCalls[i], (Call));

            if (keccak256(bytes(call.chain)) == keccak256(bytes(chain))) {
                (bool success, ) = call.target.call(call.callData);
                require(success, 'AxecutorBase: call failed');
                _processCallsWithoutGasService(call.subCalls);
            } else {
                gateway.callContract(call.chain, call.axecutor.toString(), encodedCalls[i]);
            }
        }
    }

    function _execute(string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_) internal override {
        bytes[] memory encodedCalls = new bytes[](1);
        encodedCalls[0] = payload_;

        _aggregate(encodedCalls);
    }
}
