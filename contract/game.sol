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

    struct GameCommitment {
        bytes commitment;
        bytes quantity;
        bytes asset;
    }

    mapping(uint256 => mapping(address => GameCommitment)) public gameCommitments;
    mapping(uint256 => mapping(address => bool)) public hasJoinedGame;
    mapping(uint256 => mapping(address => bool)) public hasWithdrawn;
    mapping(uint256 => uint256) public gamePlayerCounts;
    mapping(uint256 => bool) public isGameRegistered;

    event Received(address, uint);
    event ETHGameJoin(uint256 gameId, bytes quantity, address player);
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

    function joinGameETH(
        uint256 gameId, 
        bytes calldata encryptedData,
        bytes calldata quantity,
        bytes calldata asset
    ) external payable nonReentrant {
        require(msg.value > 0, "ETH value must be greater than 0");

        if (!isGameRegistered[gameId]) {
            isGameRegistered[gameId] = true;
        }

        require(!hasJoinedGame[gameId][msg.sender], "Player has already joined this game");

        gameCommitments[gameId][msg.sender] = GameCommitment({
            commitment: encryptedData,
            quantity: quantity,
            asset: asset
        });

        hasJoinedGame[gameId][msg.sender] = true;
        gamePlayerCounts[gameId]++;

        emit ETHGameJoin(gameId, quantity, msg.sender);
    }

    function hasJoined(address player, uint256 gameId)
        external
        view
        returns (bool)
    {
        return hasJoinedGame[gameId][player];
    }

    function getEthPaidForGameId(address player, uint256 gameId)
        external
        view
        returns (bytes memory)
    {
        require(
            hasJoinedGame[gameId][player],
            "User has not joined this game"
        );

        GameCommitment memory commitment = gameCommitments[gameId][player];
        return commitment.quantity;
    }

    function getGamePlayerCount(uint256 gameId) external view returns (uint256) {
        return gamePlayerCounts[gameId];
    }

    function getGameCommitment(uint256 gameId, address player) external view returns (bytes memory commitment) {
        GameCommitment memory gameData = gameCommitments[gameId][player];
        return gameData.commitment;
    }

    // Withdraw functions remain unchanged except naming
    function withdrawUSDT(TokenAmount calldata tokenAmount, address recipient) external onlyOwner {
        try IERC20Upgradeable(tokenAmount.token).transfer(recipient, tokenAmount.amount) {
            emit ERC20Withdraw(recipient, tokenAmount.token, tokenAmount.amount);
        } catch {
            revert("Failed to withdraw token");
        }
    }

    function withdrawERC20(TokenAmount calldata tokenAmount, address recipient) external onlyOwner {
        IERC20 tokenContract = IERC20(tokenAmount.token);
        bool succ = tokenContract.transfer(recipient, tokenAmount.amount);
        require(succ, "token.transfer() failed.");
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
        uint256 gameId
    ) external onlyOwner nonReentrant {
        require(accounts.length == amounts.length, "Arrays must be of equal length");
        require(isGameRegistered[gameId], "Game is not registered");

        IERC20Upgradeable usdtContract = IERC20Upgradeable(usdtToken);

        bool[] memory fails = new bool[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!hasJoinedGame[gameId][accounts[i]] || hasWithdrawn[gameId][accounts[i]]) {
                fails[i] = true;
                continue;
            }

            uint256 amount = amounts[i];
            if (usdtContract.balanceOf(address(this)) < amount) {
                fails[i] = true;
            } else {
                try usdtContract.transfer(accounts[i], amount) {
                    hasWithdrawn[gameId][accounts[i]] = true;
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
        uint256 gameId
    ) external onlyOwner nonReentrant {
        require(accounts.length == amounts.length, "Arrays must be of equal length");
        require(isGameRegistered[gameId], "Game is not registered");

        IERC20 tokenContract = IERC20(token);

        bool[] memory fails = new bool[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!hasJoinedGame[gameId][accounts[i]] || hasWithdrawn[gameId][accounts[i]]) {
                fails[i] = true;
                continue;
            }

            uint256 amount = amounts[i];
            if (tokenContract.balanceOf(address(this)) < amount) {
                fails[i] = true;
            } else {
                try tokenContract.transfer(accounts[i], amount) {
                    hasWithdrawn[gameId][accounts[i]] = true;
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
        uint256 gameId 
    ) external onlyOwner nonReentrant {
        require(accounts.length == amounts.length, "Arrays must be of equal length");
        require(isGameRegistered[gameId], "Game is not registered");

        uint256 totalAmount = 0;
        bool[] memory fails = new bool[](accounts.length);
        address[] memory accountAddresses = new address[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            accountAddresses[i] = address(accounts[i]);

            if (!hasJoinedGame[gameId][accounts[i]] || hasWithdrawn[gameId][accounts[i]]) {
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
                hasWithdrawn[gameId][accounts[i]] = true;
            }
        }

        emit ETHBatchWithdraw(accountAddresses, amounts, fails); 
    }
}
