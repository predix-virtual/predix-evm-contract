// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./Ownable.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20.Upgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PreidxGameContract is ReentrancyGuard, Ownable {

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct VoteCommitment {
        bytes commitment;
        bytes quantity;
        bytes asset;
    }

    mapping(uint256 => mapping(address => VoteCommitment)) public voteCommitments;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawn;
    mapping(uint256 => uint256) public voteCounts;
    mapping(uint256 => bool) public isVoteRegistered;

    event Received(address, uint);
    event ETHSubmitVote(uint256 voteId, bytes quantity, address voterAddress);
    event USDTBatchWithdraw(address[] accounts, uint256[] amounts, bool[] fails);
    event ETHBatchWithdraw(address[] accounts, uint256[] amounts, bool[] fails);
    event ERC20BatchWithdraw(address token, address[] accounts, uint256[] amounts, bool[] fails);
    event ETHWithdraw(address recipient, uint256 amount);
    event ERC20Withdraw(address recipient, address token, uint256 amount);

    constructor(address owner) {
        transferOwnership(owner);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function submitVoteETH(
        uint256 voteId, 
        bytes calldata encryptedData,
        bytes calldata quantity,
        bytes calldata asset
    ) external payable nonReentrant {
        require(msg.value > 0, "ETH value must be greater than 0");

        if (!isVoteRegistered[voteId]) {
            isVoteRegistered[voteId] = true;
        }

        require(!hasVoted[voteId][msg.sender], "Voter has already voted");

        voteCommitments[voteId][msg.sender] = VoteCommitment({
            commitment: encryptedData,  // Use encryptedData here
            quantity: quantity,
            asset: asset
        });

        hasVoted[voteId][msg.sender] = true;
        voteCounts[voteId]++;

        emit ETHSubmitVote(voteId, quantity, msg.sender); 
    }

    function hasVotedForVoteId(address voterAddress, uint256 voteId)
        external
        view
        returns (bool)
    {
        return hasVoted[voteId][voterAddress];
    }

    function getEthPaidForVoteId(address voterAddress, uint256 voteId)
        external
        view
        returns (bytes memory)
    {
        require(
            hasVoted[voteId][voterAddress],
            "User has not voted for this vote ID"
        );

        VoteCommitment memory commitment = voteCommitments[voteId][voterAddress];
        return commitment.quantity;
    }

    function getVoteCount(uint256 voteId) external view returns (uint256) {
        return voteCounts[voteId];
    }

    function getVoteCommitment(uint256 voteId, address voter) external view returns (bytes memory commitment) {
        VoteCommitment memory voterCommitment = voteCommitments[voteId][voter];
        return voterCommitment.commitment;
    }


    function withdrawUSDT(TokenAmount calldata tokenAmount, address recipient) external onlyOwner {
        try IERC20Upgradeable(tokenAmount.token).transfer(recipient, tokenAmount.amount) {
            emit ERC20Withdraw(recipient, tokenAmount.token, tokenAmount.amount);
        } catch Error(string memory reason) {
            revert("Failed to withdraw token");
        } catch {
            revert("Unknown error during token withdrawal");
        }
    }

    function withdrawERC20(TokenAmount calldata tokenAmount, address recipient) external onlyOwner {
        IERC20 tokenContract = IERC20(tokenAmount.token);
        bool succ = tokenContract.transfer(recipient, tokenAmount.amount);
        require(succ, "token.transfer() makes unknown error.");
        emit ERC20Withdraw(recipient, tokenAmount.token, tokenAmount.amount);
    }

    function withdrawETH(uint amount, address payable recipient) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");
        emit ETHWithdraw(recipient, amount);
    }

    function batchWithdrawUSDT(
        address usdtToken,
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 voteId
    ) external onlyOwner nonReentrant {

        require(accounts.length == amounts.length, "Arrays must be of equal length");
        require(isVoteRegistered[voteId], "Vote is not registered");

        IERC20Upgradeable usdtContract = IERC20Upgradeable(usdtToken);

        bool[] memory fails = new bool[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!hasVoted[voteId][accounts[i]] || hasWithdrawn[voteId][accounts[i]]) {
                fails[i] = true;
                continue;
            }

            uint256 amount = amounts[i];
            if (usdtContract.balanceOf(address(this)) < amount) {
                fails[i] = true;
            } else {
                try usdtContract.transfer(accounts[i], amount) {
                    hasWithdrawn[voteId][accounts[i]] = true;
                } catch {
                    fails[i] = true;
                }
            }
        }

        emit USDTBatchWithdraw(accounts, amounts, fails);
    }

     function batchWithdrawERC20(
        address token,
        address[] memory accounts,
        uint256[] memory amounts,
        uint256 voteId
    ) external onlyOwner nonReentrant {

        require(accounts.length == amounts.length, "Arrays must be of equal length");
        require(isVoteRegistered[voteId], "Vote is not registered");

        IERC20 tokenContract = IERC20(token);

        bool[] memory fails = new bool[](accounts.length);
        
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!hasVoted[voteId][accounts[i]] || hasWithdrawn[voteId][accounts[i]]) {
                fails[i] = true;
                continue;
            }

            uint256 amount = amounts[i];
            if (tokenContract.balanceOf(address(this)) < amount) {
                fails[i] = true;
            } else {
                try tokenContract.transfer(accounts[i], amount) {
                    hasWithdrawn[voteId][accounts[i]] = true;
                } catch {
                    fails[i] = true;
                }
            }
        }

        emit ERC20BatchWithdraw(token, accounts, amounts, fails);
    }

    function batchWithdrawETH(
        address payable[] memory accounts,
        uint256[] memory amounts,
        uint256 voteId 
    ) external onlyOwner nonReentrant {
        
        require(accounts.length == amounts.length, "Arrays must be of equal length");
        require(isVoteRegistered[voteId], "Vote is not registered");
        
        uint256 totalAmount = 0;
        bool[] memory fails = new bool[](accounts.length);
        address[] memory accountAddresses = new address[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            accountAddresses[i] = address(accounts[i]);  // Convert to address

            if (!hasVoted[voteId][accounts[i]] || hasWithdrawn[voteId][accounts[i]]) {
                fails[i] = true;
                continue; 
            }

            if (address(this).balance < amounts[i]) {
                fails[i] = true;
            } else {
                totalAmount += amounts[i];
            }
        }

        require(totalAmount <= address(this).balance, "Not Enough ETH in Contract");

        for (uint256 i = 0; i < accounts.length; i++) {
            if (!fails[i]) {
                (bool success, ) = accounts[i].call{value: amounts[i]}("");
                require(success, "Withdrawal to account failed");
                hasWithdrawn[voteId][accounts[i]] = true;
            }
        }
        
        emit ETHBatchWithdraw(accountAddresses, amounts, fails); 
    }
}
