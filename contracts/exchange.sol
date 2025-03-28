// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = '';

    // TODO: paste token contract address here
    // e.g. tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;                                  // TODO: paste token contract address here
    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // Liquidity pool shares
    mapping(address => uint) private lps;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;      

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;                
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    uint private multiplier = 10**5;

    constructor() {}
    

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10**5;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // Function getReserves
    function getReserves() public view returns (uint, uint) {
        return (eth_reserves, token_reserves);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    
    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity() 
        external 
        payable
    {
        uint ethAmount = msg.value;
        uint tokenAmount = ethAmount;

        uint shareAmount = ethAmount * total_shares / eth_reserves;
        
        require(token.transferFrom(msg.sender, address(this), tokenAmount));

        lps[msg.sender] += shareAmount;
        total_shares += shareAmount;
        eth_reserves += ethAmount;
        token_reserves += tokenAmount;
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH)
        public 
        payable
    {
        require(amountETH > 0);
        require(amountETH < eth_reserves);

        uint shareAmount = amountETH * total_shares / eth_reserves;
        require(shareAmount <= lps[msg.sender]);

        uint tokenAmount = amountETH * token_reserves / eth_reserves;

        payable(address(this)).transfer(amountETH);
        require(token.transferFrom(address(this), msg.sender, amountETH));

        lps[msg.sender] -= shareAmount;
        total_shares -= shareAmount;
        eth_reserves -= amountETH;
        token_reserves -= tokenAmount;
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity()
        external
        payable
    {
        uint userShares = lps[msg.sender];
        require(userShares > 0);

        uint totalEthAmount = userShares * eth_reserves / total_shares;
        uint totalTokenAmount = userShares * token_reserves / total_shares;
        require(totalEthAmount < eth_reserves);

        payable(address(this)).transfer(totalEthAmount);
        require(token.transferFrom(address(this), msg.sender, totalTokenAmount));

        lps[msg.sender] = 0;
        total_shares -= userShares;
        eth_reserves -= totalEthAmount;
        token_reserves -= totalTokenAmount;
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens)
        external 
        payable
    {
        require(amountTokens < token_reserves);
        uint amountETH = eth_reserves * amountTokens / (token_reserves + amountTokens);

        payable(address(this)).transfer(amountETH);
        require(token.transferFrom(msg.sender, address(this), amountTokens));

        eth_reserves += amountTokens;
        token_reserves -= amountETH;
    }



    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens()
        external
        payable 
    {
        uint amountETH = msg.value;
        require(amountETH < eth_reserves);
        uint amountTokens = token_reserves * amountETH / (eth_reserves + amountETH);
        
        require(token.transferFrom(address(this), msg.sender, amountTokens));

        eth_reserves += amountETH;
        token_reserves -= amountTokens;
    }
}