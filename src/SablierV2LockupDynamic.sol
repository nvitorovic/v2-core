// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.18;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";
import { IERC721Metadata } from "@openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import { PRBMathCastingUint128 as CastingUint128 } from "@prb/math/casting/Uint128.sol";
import { PRBMathCastingUint40 as CastingUint40 } from "@prb/math/casting/Uint40.sol";
import { SD59x18 } from "@prb/math/SD59x18.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

import { SablierV2Lockup } from "./abstracts/SablierV2Lockup.sol";
import { ISablierV2Comptroller } from "./interfaces/ISablierV2Comptroller.sol";
import { ISablierV2Lockup } from "./interfaces/ISablierV2Lockup.sol";
import { ISablierV2LockupDynamic } from "./interfaces/ISablierV2LockupDynamic.sol";
import { ISablierV2LockupRecipient } from "./interfaces/hooks/ISablierV2LockupRecipient.sol";
import { ISablierV2LockupSender } from "./interfaces/hooks/ISablierV2LockupSender.sol";
import { ISablierV2NFTDescriptor } from "./interfaces/ISablierV2NFTDescriptor.sol";
import { Errors } from "./libraries/Errors.sol";
import { Helpers } from "./libraries/Helpers.sol";
import { Lockup, LockupDynamic } from "./types/DataTypes.sol";

/*

███████╗ █████╗ ██████╗ ██╗     ██╗███████╗██████╗     ██╗   ██╗██████╗
██╔════╝██╔══██╗██╔══██╗██║     ██║██╔════╝██╔══██╗    ██║   ██║╚════██╗
███████╗███████║██████╔╝██║     ██║█████╗  ██████╔╝    ██║   ██║ █████╔╝
╚════██║██╔══██║██╔══██╗██║     ██║██╔══╝  ██╔══██╗    ╚██╗ ██╔╝██╔═══╝
███████║██║  ██║██████╔╝███████╗██║███████╗██║  ██║     ╚████╔╝ ███████╗
╚══════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝╚══════╝╚═╝  ╚═╝      ╚═══╝  ╚══════╝

██╗      ██████╗  ██████╗██╗  ██╗██╗   ██╗██████╗     ██████╗ ██╗   ██╗███╗   ██╗ █████╗ ███╗   ███╗██╗ ██████╗
██║     ██╔═══██╗██╔════╝██║ ██╔╝██║   ██║██╔══██╗    ██╔══██╗╚██╗ ██╔╝████╗  ██║██╔══██╗████╗ ████║██║██╔════╝
██║     ██║   ██║██║     █████╔╝ ██║   ██║██████╔╝    ██║  ██║ ╚████╔╝ ██╔██╗ ██║███████║██╔████╔██║██║██║
██║     ██║   ██║██║     ██╔═██╗ ██║   ██║██╔═══╝     ██║  ██║  ╚██╔╝  ██║╚██╗██║██╔══██║██║╚██╔╝██║██║██║
███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╔╝██║         ██████╔╝   ██║   ██║ ╚████║██║  ██║██║ ╚═╝ ██║██║╚██████╗
╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝         ╚═════╝    ╚═╝   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝ ╚═════╝

*/

/// @title SablierV2LockupDynamic
/// @notice See the documentation in {ISablierV2LockupDynamic}.
contract SablierV2LockupDynamic is
    ISablierV2LockupDynamic, // one dependency
    ERC721("Sablier V2 Lockup Dynamic NFT", "SAB-V2-LOCKUP-DYN"), // six dependencies
    SablierV2Lockup // eleven dependencies
{
    using CastingUint128 for uint128;
    using CastingUint40 for uint40;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                  PUBLIC CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2LockupDynamic
    uint256 public immutable override MAX_SEGMENT_COUNT;

    /*//////////////////////////////////////////////////////////////////////////
                                  PRIVATE STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Counter for stream ids, used in the create functions.
    uint256 private _nextStreamId;

    /// @dev Lockup dynamic streams mapped by unsigned integers ids.
    mapping(uint256 id => LockupDynamic.Stream stream) private _streams;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Emits a {TransferAdmin} event.
    /// @param initialAdmin The address of the initial contract admin.
    /// @param initialComptroller The address of the initial comptroller.
    /// @param initialNFTDescriptor The address of the NFT descriptor contract.
    /// @param maxSegmentCount The maximum number of segments permitted in a stream.
    constructor(
        address initialAdmin,
        ISablierV2Comptroller initialComptroller,
        ISablierV2NFTDescriptor initialNFTDescriptor,
        uint256 maxSegmentCount
    )
        SablierV2Lockup(initialAdmin, initialComptroller, initialNFTDescriptor)
    {
        MAX_SEGMENT_COUNT = maxSegmentCount;
        _nextStreamId = 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2Lockup
    function getAsset(uint256 streamId) external view override isNonNull(streamId) returns (IERC20 asset) {
        asset = _streams[streamId].asset;
    }

    /// @inheritdoc ISablierV2Lockup
    function getDepositAmount(uint256 streamId)
        external
        view
        override
        isNonNull(streamId)
        returns (uint128 depositAmount)
    {
        depositAmount = _streams[streamId].amounts.deposit;
    }

    /// @inheritdoc ISablierV2Lockup
    function getEndTime(uint256 streamId) external view override isNonNull(streamId) returns (uint40 endTime) {
        endTime = _streams[streamId].endTime;
    }

    /// @inheritdoc ISablierV2LockupDynamic
    function getRange(uint256 streamId)
        external
        view
        override
        isNonNull(streamId)
        returns (LockupDynamic.Range memory range)
    {
        range = LockupDynamic.Range({ start: _streams[streamId].startTime, end: _streams[streamId].endTime });
    }

    /// @inheritdoc ISablierV2Lockup
    function getRecipient(uint256 streamId) external view override returns (address recipient) {
        // Checks: the stream NFT exists.
        _requireMinted({ tokenId: streamId });

        // The owner of the stream NFT is the recipient.
        recipient = _ownerOf(streamId);
    }

    /// @inheritdoc ISablierV2LockupDynamic
    function getSegments(uint256 streamId)
        external
        view
        override
        isNonNull(streamId)
        returns (LockupDynamic.Segment[] memory segments)
    {
        segments = _streams[streamId].segments;
    }

    /// @inheritdoc ISablierV2Lockup
    function getSender(uint256 streamId) external view override isNonNull(streamId) returns (address sender) {
        sender = _streams[streamId].sender;
    }

    /// @inheritdoc ISablierV2Lockup
    function getStartTime(uint256 streamId) external view override isNonNull(streamId) returns (uint40 startTime) {
        startTime = _streams[streamId].startTime;
    }

    /// @inheritdoc ISablierV2Lockup
    function getStatus(uint256 streamId)
        public
        view
        virtual
        override(ISablierV2Lockup, SablierV2Lockup)
        returns (Lockup.Status status)
    {
        status = _streams[streamId].status;
    }

    /// @inheritdoc ISablierV2LockupDynamic
    function getStream(uint256 streamId)
        external
        view
        override
        isNonNull(streamId)
        returns (LockupDynamic.Stream memory stream)
    {
        stream = _streams[streamId];
    }

    /// @inheritdoc ISablierV2Lockup
    function getWithdrawnAmount(uint256 streamId)
        external
        view
        override
        isNonNull(streamId)
        returns (uint128 withdrawnAmount)
    {
        withdrawnAmount = _streams[streamId].amounts.withdrawn;
    }

    /// @inheritdoc ISablierV2Lockup
    function isCancelable(uint256 streamId) external view override isNonNull(streamId) returns (bool result) {
        result = _streams[streamId].isCancelable;
    }

    /// @inheritdoc ISablierV2Lockup
    function nextStreamId() external view override returns (uint256) {
        return _nextStreamId;
    }

    /// @inheritdoc ISablierV2Lockup
    function returnableAmountOf(uint256 streamId)
        external
        view
        override
        isNonNull(streamId)
        returns (uint128 returnableAmount)
    {
        // If the stream is active, calculate the returnable amount. In all other cases, the returnable amount is
        // implicitly zero.
        if (_streams[streamId].status == Lockup.Status.ACTIVE) {
            unchecked {
                // No need for an assertion here, since {_streamedAmountOf} checks that the deposit amount is greater
                // than or equal to the streamed amount.
                returnableAmount = _streams[streamId].amounts.deposit - _streamedAmountOf(streamId);
            }
        }
    }

    /// @inheritdoc ISablierV2LockupDynamic
    function streamedAmountOf(uint256 streamId)
        public
        view
        override(ISablierV2Lockup, ISablierV2LockupDynamic)
        isNonNull(streamId)
        returns (uint128 streamedAmount)
    {
        streamedAmount = _streamedAmountOf(streamId);
    }

    /// @inheritdoc ERC721
    function tokenURI(uint256 streamId) public view override(IERC721Metadata, ERC721) returns (string memory uri) {
        // Checks: the stream NFT exists.
        _requireMinted({ tokenId: streamId });

        // Generate the URI describing the stream NFT
        uri = _nftDescriptor.tokenURI(this, streamId);
    }

    /// @inheritdoc ISablierV2Lockup
    function withdrawableAmountOf(uint256 streamId)
        public
        view
        override(ISablierV2Lockup, SablierV2Lockup)
        isNonNull(streamId)
        returns (uint128 withdrawableAmount)
    {
        unchecked {
            withdrawableAmount = _streamedAmountOf(streamId) - _streams[streamId].amounts.withdrawn;
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                         USER-FACING NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISablierV2Lockup
    function cancel(uint256 streamId)
        public
        override(ISablierV2Lockup, SablierV2Lockup)
        noDelegateCall
        isActive(streamId)
        onlySenderOrRecipient(streamId)
    {
        // Checks: the stream is cancelable.
        if (!_streams[streamId].isCancelable) {
            revert Errors.SablierV2Lockup_StreamNonCancelable(streamId);
        }

        // Load the stream in memory.
        LockupDynamic.Stream memory stream = _streams[streamId];

        // Calculate the sender's and the recipient's amount.
        uint128 streamedAmount = _streamedAmountOf(streamId);
        uint128 senderAmount;
        uint128 recipientAmount;
        unchecked {
            // Equivalent to {returnableAmountOf}.
            senderAmount = stream.amounts.deposit - streamedAmount;
            // Equivalent to {withdrawableAmountOf}.
            recipientAmount = streamedAmount - stream.amounts.withdrawn;
        }

        // Load the sender and the recipient in memory, as they are needed multiple times below.
        address sender = _streams[streamId].sender;
        address recipient = _ownerOf(streamId);

        // Effects: mark the stream as canceled.
        _streams[streamId].status = Lockup.Status.CANCELED;
        _streams[streamId].isCancelable = false;

        if (recipientAmount > 0) {
            // Effects: add the recipient's amount to the withdrawn amount.
            unchecked {
                _streams[streamId].amounts.withdrawn += recipientAmount;
            }

            // Interactions: withdraw the assets to the recipient.
            stream.asset.safeTransfer({ to: recipient, value: recipientAmount });
        }

        // Interactions: return the assets to the sender, if any.
        if (senderAmount > 0) {
            stream.asset.safeTransfer({ to: sender, value: senderAmount });
        }

        // Interactions: if the `msg.sender` is the sender and the recipient is a contract, try to invoke the cancel
        // hook on the recipient without reverting if the hook is not implemented, and without bubbling up any
        // potential revert.
        if (msg.sender == sender) {
            if (recipient.code.length > 0) {
                try ISablierV2LockupRecipient(recipient).onStreamCanceled({
                    streamId: streamId,
                    senderAmount: senderAmount,
                    recipientAmount: recipientAmount
                }) { } catch { }
            }
        }
        // Interactions: if the `msg.sender` is the recipient and the sender is a contract, try to invoke the cancel
        // hook on the sender without reverting if the hook is not implemented, and also without bubbling up any
        // potential revert.
        else {
            if (sender.code.length > 0) {
                try ISablierV2LockupSender(sender).onStreamCanceled({
                    streamId: streamId,
                    senderAmount: senderAmount,
                    recipientAmount: recipientAmount
                }) { } catch { }
            }
        }

        // Log the cancellation.
        emit ISablierV2Lockup.CancelLockupStream(streamId, sender, recipient, senderAmount, recipientAmount);
    }

    /// @inheritdoc ISablierV2LockupDynamic
    function createWithDeltas(LockupDynamic.CreateWithDeltas calldata params)
        external
        override
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks: check the deltas and generate the canonical segments.
        LockupDynamic.Segment[] memory segments = Helpers.checkDeltasAndCalculateMilestones(params.segments);

        // Checks, Effects and Interactions: create the stream.
        streamId = _createWithMilestones(
            LockupDynamic.CreateWithMilestones({
                asset: params.asset,
                broker: params.broker,
                cancelable: params.cancelable,
                recipient: params.recipient,
                segments: segments,
                sender: params.sender,
                startTime: uint40(block.timestamp),
                totalAmount: params.totalAmount
            })
        );
    }

    /// @inheritdoc ISablierV2LockupDynamic
    function createWithMilestones(LockupDynamic.CreateWithMilestones calldata params)
        external
        override
        noDelegateCall
        returns (uint256 streamId)
    {
        // Checks, Effects and Interactions: create the stream.
        streamId = _createWithMilestones(params);
    }

    /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Calculates the streamed amount for a stream with multiple segments.
    ///
    /// Notes:
    ///
    /// 1. Normalization to 18 decimals is not needed because there is no mix of amounts with different decimals.
    /// 2. This function must be called only when the end time of the stream is in the future so that the
    /// the loop below does not panic with an "index out of bounds" error.
    function _calculateStreamedAmountForMultipleSegments(uint256 streamId)
        internal
        view
        returns (uint128 streamedAmount)
    {
        unchecked {
            uint40 currentTime = uint40(block.timestamp);

            // Sum the amounts in all preceding segments.
            uint128 previousSegmentAmounts;
            uint40 currentSegmentMilestone = _streams[streamId].segments[0].milestone;
            uint256 index = 1;
            while (currentSegmentMilestone < currentTime) {
                previousSegmentAmounts += _streams[streamId].segments[index - 1].amount;
                currentSegmentMilestone = _streams[streamId].segments[index].milestone;
                index += 1;
            }

            // After exiting the loop, the current segment is at index `index - 1`, and the previous segment
            // is at `index - 2` (when there are two or more segments).
            SD59x18 currentSegmentAmount = _streams[streamId].segments[index - 1].amount.intoSD59x18();
            SD59x18 currentSegmentExponent = _streams[streamId].segments[index - 1].exponent.intoSD59x18();
            currentSegmentMilestone = _streams[streamId].segments[index - 1].milestone;

            uint40 previousMilestone;
            if (index > 1) {
                // If the current segment is at index >= 2, use the previous segment's milestone.
                previousMilestone = _streams[streamId].segments[index - 2].milestone;
            } else {
                // Otherwise, the current segment is the first, so consider the start time the previous milestone.
                previousMilestone = _streams[streamId].startTime;
            }

            // Calculate how much time has passed since the segment started, and the total time of the segment.
            SD59x18 elapsedSegmentTime = (currentTime - previousMilestone).intoSD59x18();
            SD59x18 totalSegmentTime = (currentSegmentMilestone - previousMilestone).intoSD59x18();

            // Divide the elapsed segment time by the total duration of the segment.
            SD59x18 elapsedSegmentTimePercentage = elapsedSegmentTime.div(totalSegmentTime);

            // Calculate the streamed amount using the special formula.
            SD59x18 multiplier = elapsedSegmentTimePercentage.pow(currentSegmentExponent);
            SD59x18 segmentStreamedAmount = multiplier.mul(currentSegmentAmount);

            // Although the segment streamed amount should never exceed the total segment amount, this condition is
            // checked without asserting to avoid locking funds in case of a bug. If this situation occurs, the amount
            // streamed in the segment is considered zero, and the segment is effectively voided.
            if (segmentStreamedAmount.gt(currentSegmentAmount)) {
                return previousSegmentAmounts;
            }

            // Calculate the total streamed amount by adding the previous segment amounts and the amount streamed in
            // the current segment. Casting to uint128 is safe due to the if statement above.
            streamedAmount = previousSegmentAmounts + uint128(segmentStreamedAmount.intoUint256());
        }
    }

    /// @dev Calculates the streamed amount for a stream with one segment. Normalization to 18 decimals is not
    /// needed because there is no mix of amounts with different decimals.
    function _calculateStreamedAmountForOneSegment(uint256 streamId) internal view returns (uint128 streamedAmount) {
        unchecked {
            // Calculate how much time has passed since the stream started, and the total time of the stream.
            SD59x18 elapsedTime = (uint40(block.timestamp) - _streams[streamId].startTime).intoSD59x18();
            SD59x18 totalTime = (_streams[streamId].endTime - _streams[streamId].startTime).intoSD59x18();

            // Divide the elapsed time by the total duration of the stream.
            SD59x18 elapsedTimePercentage = elapsedTime.div(totalTime);

            // Cast the stream parameters to SD59x18.
            SD59x18 exponent = _streams[streamId].segments[0].exponent.intoSD59x18();
            SD59x18 depositAmount = _streams[streamId].amounts.deposit.intoSD59x18();

            // Calculate the streamed amount using the special formula.
            SD59x18 multiplier = elapsedTimePercentage.pow(exponent);
            SD59x18 streamedAmountSd = multiplier.mul(depositAmount);

            // Although the streamed amount should never exceed the deposit amount, this condition is checked
            // without asserting to avoid locking funds in case of a bug. If this situation occurs, the withdrawn
            // amount is considered to be the streamed amount, and the stream is effectively frozen.
            if (streamedAmountSd.gt(depositAmount)) {
                return _streams[streamId].amounts.withdrawn;
            }

            // Cast the streamed amount to uint128. This is safe due to the check above.
            streamedAmount = uint128(streamedAmountSd.intoUint256());
        }
    }

    /// @inheritdoc SablierV2Lockup
    function _isCallerStreamRecipientOrApproved(uint256 streamId) internal view override returns (bool result) {
        address recipient = _ownerOf(streamId);
        result = (
            msg.sender == recipient || isApprovedForAll({ owner: recipient, operator: msg.sender })
                || getApproved(streamId) == msg.sender
        );
    }

    /// @inheritdoc SablierV2Lockup
    function _isCallerStreamSender(uint256 streamId) internal view override returns (bool result) {
        result = msg.sender == _streams[streamId].sender;
    }

    /// @inheritdoc SablierV2Lockup
    function _ownerOf(uint256 tokenId) internal view override(ERC721, SablierV2Lockup) returns (address owner) {
        owner = ERC721._ownerOf(tokenId);
    }

    /// @dev See the documentation for the public functions that call this internal function.
    function _streamedAmountOf(uint256 streamId) internal view returns (uint128 streamedAmount) {
        // If the stream is canceled or depleted, return the withdrawn amount.
        if (_streams[streamId].status != Lockup.Status.ACTIVE) {
            return _streams[streamId].amounts.withdrawn;
        }

        // If the start time is greater than or equal to the block timestamp, return zero.
        uint40 currentTime = uint40(block.timestamp);
        if (_streams[streamId].startTime >= currentTime) {
            return 0;
        }

        // Load the segment count and the end time.
        uint256 segmentCount = _streams[streamId].segments.length;
        uint40 endTime = _streams[streamId].endTime;

        // If the current time is greater than or equal to the end time, return the deposit amount.
        if (currentTime >= endTime) {
            return _streams[streamId].amounts.deposit;
        }

        if (segmentCount > 1) {
            // If there's more than one segment, we may have to iterate over all of them.
            streamedAmount = _calculateStreamedAmountForMultipleSegments(streamId);
        } else {
            // Otherwise, there is only one segment, and the calculation is simple.
            streamedAmount = _calculateStreamedAmountForOneSegment(streamId);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                           INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev See the documentation for the public functions that call this internal function.
    function _burn(uint256 tokenId) internal override(ERC721, SablierV2Lockup) {
        ERC721._burn(tokenId);
    }

    /// @dev See the documentation for the public functions that call this internal function.
    function _createWithMilestones(LockupDynamic.CreateWithMilestones memory params)
        internal
        returns (uint256 streamId)
    {
        // Safe Interactions: query the protocol fee. This is safe because it's a known Sablier contract that does
        // not call other unknown contracts..
        UD60x18 protocolFee = comptroller.protocolFees(params.asset);

        // Checks: check the fees and calculate the fee amounts.
        Lockup.CreateAmounts memory createAmounts =
            Helpers.checkAndCalculateFees(params.totalAmount, protocolFee, params.broker.fee, MAX_FEE);

        // Checks: validate the arguments.
        Helpers.checkCreateDynamicParams(createAmounts.deposit, params.segments, MAX_SEGMENT_COUNT, params.startTime);

        // Load the stream id.
        streamId = _nextStreamId;

        // Load the segment count.
        uint256 segmentCount = params.segments.length;

        // Effects: create the stream.
        LockupDynamic.Stream storage stream = _streams[streamId];
        stream.amounts = Lockup.Amounts({ deposit: createAmounts.deposit, withdrawn: 0 });
        stream.asset = params.asset;
        stream.isCancelable = params.cancelable;
        stream.sender = params.sender;
        stream.status = Lockup.Status.ACTIVE;

        unchecked {
            // The segment count cannot be zero at this point.
            stream.endTime = params.segments[segmentCount - 1].milestone;
            stream.startTime = params.startTime;

            // Effects: store the segments. Copying an array from memory to storage is not supported, so this has
            // to be done manually. See https://github.com/ethereum/solidity/issues/12783
            for (uint256 i = 0; i < segmentCount; ++i) {
                stream.segments.push(params.segments[i]);
            }

            // Effects: bump the next stream id and record the protocol fee.
            // Using unchecked arithmetic because these calculations cannot realistically overflow, ever.
            _nextStreamId = streamId + 1;
            protocolRevenues[params.asset] += createAmounts.protocolFee;
        }

        // Effects: mint the NFT to the recipient.
        _mint({ to: params.recipient, tokenId: streamId });

        // Interactions: transfer the deposit and the protocol fee.
        // Using unchecked arithmetic because the deposit and the protocol fee are bounded by the total amount.
        unchecked {
            params.asset.safeTransferFrom({
                from: msg.sender,
                to: address(this),
                value: createAmounts.deposit + createAmounts.protocolFee
            });
        }

        // Interactions: pay the broker fee, if not zero.
        if (createAmounts.brokerFee > 0) {
            params.asset.safeTransferFrom({ from: msg.sender, to: params.broker.account, value: createAmounts.brokerFee });
        }

        // Log the newly created stream, and the address that funded it.
        emit ISablierV2LockupDynamic.CreateLockupDynamicStream({
            streamId: streamId,
            funder: msg.sender,
            sender: params.sender,
            recipient: params.recipient,
            amounts: createAmounts,
            asset: params.asset,
            cancelable: params.cancelable,
            segments: params.segments,
            range: LockupDynamic.Range({ start: stream.startTime, end: stream.endTime }),
            broker: params.broker.account
        });
    }

    /// @dev See the documentation for the public functions that call this internal function.
    function _renounce(uint256 streamId) internal override {
        // Checks: the stream is cancelable.
        if (!_streams[streamId].isCancelable) {
            revert Errors.SablierV2Lockup_StreamNonCancelable(streamId);
        }

        // Effects: make the stream non-cancelable.
        _streams[streamId].isCancelable = false;

        // Interactions: if the recipient is a contract, try to invoke the renounce hook on the recipient without
        // reverting if the hook is not implemented, and also without bubbling up any potential revert.
        address recipient = _ownerOf(streamId);
        if (recipient.code.length > 0) {
            try ISablierV2LockupRecipient(recipient).onStreamRenounced(streamId) { } catch { }
        }

        // Log the renouncement.
        emit ISablierV2Lockup.RenounceLockupStream(streamId);
    }

    /// @dev See the documentation for the public functions that call this internal function.
    function _withdraw(uint256 streamId, address to, uint128 amount) internal override {
        // Checks: the amount is not zero.
        if (amount == 0) {
            revert Errors.SablierV2Lockup_WithdrawAmountZero(streamId);
        }

        unchecked {
            // Calculate the withdrawable amount.
            uint128 withdrawableAmount = _streamedAmountOf(streamId) - _streams[streamId].amounts.withdrawn;

            // Checks: the withdraw amount is not greater than the withdrawable amount.
            if (amount > withdrawableAmount) {
                revert Errors.SablierV2Lockup_WithdrawAmountGreaterThanWithdrawableAmount(
                    streamId, amount, withdrawableAmount
                );
            }

            // Effects: update the withdrawn amount.
            _streams[streamId].amounts.withdrawn += amount;
        }

        // Load the stream and the recipient in memory, as they will be needed below.
        LockupDynamic.Stream memory stream = _streams[streamId];
        address recipient = _ownerOf(streamId);

        // Assert that the deposit amount is greater than or equal to the withdrawn amount.
        assert(stream.amounts.deposit >= stream.amounts.withdrawn);

        // Effects: if the entire deposit amount is now withdrawn, mark the stream as depleted.
        if (stream.amounts.deposit == stream.amounts.withdrawn) {
            _streams[streamId].status = Lockup.Status.DEPLETED;

            // A depleted stream cannot be canceled anymore.
            _streams[streamId].isCancelable = false;
        }

        // Interactions: perform the ERC-20 transfer.
        stream.asset.safeTransfer({ to: to, value: amount });

        // Interactions: if the `msg.sender` is not the recipient and the recipient is a contract, try to invoke the
        // withdraw hook on it without reverting if the hook is not implemented, and also without bubbling up
        // any potential revert.
        if (msg.sender != recipient && recipient.code.length > 0) {
            try ISablierV2LockupRecipient(recipient).onStreamWithdrawn({
                streamId: streamId,
                caller: msg.sender,
                to: to,
                amount: amount
            }) { } catch { }
        }

        // Log the withdrawal.
        emit ISablierV2Lockup.WithdrawFromLockupStream(streamId, to, amount);
    }
}
