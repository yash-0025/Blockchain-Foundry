    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 * @title DSC Engine
 * @author Yash Patel
 * The system is designed to be as minimal as possible and have the tokkens maintain a 1 token == 1 dollar peg.
 * This StableCoin has the properties :TFR
 *      Exogenous Collateral
 *      Dollar pegged
 *      Alogorithmatically stable
 *
 * It is similar to DAI had no governance , no fees, and was only bakced bu WETH and WBTC
 *
 * Our DSC system should always be "overcollateralized". At no point should the value of all collateral <= the $ backed value of all the DSC.
 * @notice  This contract is the core of the DSC System . It handles all the logic for minting and redeeming DSC as well as depositing and withdrawing collateral
 * @notice This contract is very loosely based on the MakerDAO DSS(DAI) system
 */

contract DSCEngine is ReentrancyGuard {
    //..............ERRORS...............//
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();


    //............TYPES.............//
    using OracleLib for AggregatorV3Interface;


    //............STATE--VARIABLES.............//

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_priceFeeds; // tokenPriceFeed
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited; // how much token the user has deposited to know how much collateral is deposited.
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;

    address[] private s_collateralTokens;




    DecentralizedStableCoin private immutable i_dsc;

    
    //............EVENTS.............//
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom,address indexed redeemedTo, address token, uint256  amount);



    //............MODIFIERS.............//

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    } 


    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    //............FUNCTIONS.............//
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        // For example ETH/USD BTC/USD MKR/USD etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //............EXTERNAL--FUNCTIONS.............//

/*
 * 
 * @param tokenCollateralAddress The address of the token to deposit as colalteral 
 * @param amountCollateral  The amount of collateral to deposit
 * @param amountDscToMint The amount of decentralized stable coin
 * @notice Thsi function will deposit colalteral and mint DSC in one transaction 
*/

    function depositCollateralAndMintDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }
 
    /*
     * @param tokenCollateralAddress The Address of the token to deposit as collateral.
     * @notice follows CEI
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender,tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
       
    } 

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);

    }


/// In order to redeem collateral
// 1. Health factor must be over 1 after collateral pulled
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public  moreThanZero(amountCollateral) nonReentrant
    {
        // s_collateralDeposited[msg.sender][tokenCollateralAddress] -= amountCollateral;
        // emit CollateralRedeemed(msg.sender,  tokenCollateralAddress, amountCollateral);
        // bool success = IERC20(tokenCollateralAddress).transfer(msg.sender, amountCollateral);
        // if(!success) {
        //     revert DSCEngine__TransferFailed();
        // }
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

/*
 * @notice follows CEI
 * @param amountDscToMint  The amount of decentralised stablecoin to mint
 * @notice they must have more collateral value than the threshold
 */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if(!minted) {
            revert DSCEngine__MintFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        // s_DSCMinted[msg.sender] -= amount;
        // bool success = i_dsc.transferFrom(msg.sender, address(this), amount);
        // if(!success) {
        //     revert DSCEngine__TransferFailed();
        // }
        // i_dsc.burn(amount);

        _burnDsc(amount, msg.sender, msg.sender);
        // back up if this affects the health factor function
        _revertIfHealthFactorIsBroken(msg.sender); 

    }
// If someone is under collateralized we will pay you to liquidate them
// like if someone has 75$ backing 50$ DSC
// Liquidator will take the 75$ backing and burns off the 50$ DSC
/* 
 * @param collateral  - The erc20 collateral address to liquidate from the user
 * @param user - The user who has brokent the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR   
 * @param debtToCover  The amount of DSC you want to improve the users health factor
 * @notice You can partially liquidate a user.
 * @notice You will get a liquidation bonus for taking the users funds
 * @notice  This function working assumes the protocol will be roughly 200% overcollateralized in order for this work.
 * LIke If THERE IS 50$ FOR 50DSC THEN the liquidator can get 75$ for 50 DSC which will act as a bonus for the liquidator.
 * @notice A known bug would be if the protocol were 100% or less collateralized , then we wouldn't be able to incentive the liquidator
 * For Example if the price of the collateral plummeted before anyone could be liquidated
 * 
 */
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
        // Need to check healthfactor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        // WE want to burn the DSC "Debt"
        // And take their collateral
        // Bas User : $140 ETH, 100$ DSC
        // DebtToCover : 100$
        // 100$ of DSC is equal to how much of ETH
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // WE are giving them a 10% bonus
        // So we are giving the liquidator 110$ o WETH for 100 DSC
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral( collateral,totalCollateralToRedeem, user,msg.sender);
        //WE need to burn the DSC 
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if(endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);

    }

    function calculateHealthFActor(uint256 totalDscMinted, uint256 collateralValueInUsd) external pure returns(uint256){
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }
    function getHealthFactor(address user) external view returns(uint256) {
        return _healthFactor(user);
    }




        //............PRIVATE---&---INTERNAL---FUNCTIONS.............//\
    
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(
            dscFrom, address(this), amountDscToBurn);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from,to,tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if(!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _calculateHealthFactor(uint256 totalDscMinted, uint256 collateralValueInUsd) internal pure returns(uint256) {
        if(totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * 1e18) / totalDscMinted;
    }

/*
 * Returns how close to liquidate a user is  
 * If a user goes below 1 then they can get liquidated 
 */
    function _healthFactor(address user) private view returns(uint256) {
        // total DSC Minted
        // Total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        // return (collateralValueInUsd / totalDscMinted);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD)/ LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        // 1000 Eth * 50 = 50,000 / 100 = 500
        // 150 $ ETH / 100 DSC = 1.5
        // 150 * 50 = 7500

    }

    function _revertIfHealthFactorIsBroken(address user)  internal view {
        // 1. Check health factor (do they have enough collateral?)
        // 2. Revert if they don't 
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        } 
    }


        //............PUBLIC---&---EXTERNAL---FUNCTIONS.............//
        function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns(uint256) {
            // price of the ETH token
            // $/ETH ?
            // 2000$ / ETH. $1000=0.5 ETH
            // usdAmountInWei divided by price
            AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
            (,int256 price,,,) = priceFeed.latestRoundData();
            // ($10e18 * 1e18) / ($2000e8 * 1e10)
            return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
        }

    function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValueInUsd){
        // we will loop through each collateral token, get the amount they have deposited and ap it to the price to get the USD value
        for(uint256 i = 0; i<s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;

    }

    function getUsdValue(address token, uint256 amount) public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000$
        // The returned value from CL will be 1000 * 1e8
        // 1e8 = 1 * 10^8 = 100000000
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user) external view returns(uint256 totalDscMinted, uint256 collateralValueInUsd) {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getCollateralToken() external view returns(address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return address(i_dsc);
    }

}

