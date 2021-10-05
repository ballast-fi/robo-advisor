// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/ChainLinkOracle.sol";
import "./interfaces/IBaseContract.sol";

contract PriceOracle is Ownable, IBaseContract {
    using SafeMath for uint256;

    uint256 constant private ONE_18 = 10**18;
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant public COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address constant public WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant public DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant public USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant public USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant stkAAVE = address(0x4da27a545c0c5B758a6BA100e3a049001de870f5);

    // underlying -> chainlink feed see https://docs.chain.link/docs/reference-contracts
    mapping (address => address) public priceFeedsUSD;
    mapping (address => address) public priceFeedsETH;

    constructor() public {
        // USD feeds
        priceFeedsUSD[WETH] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // WETH
        priceFeedsUSD[COMP] = 0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5; // COMP
        priceFeedsUSD[WBTC] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c; // wBTC
        priceFeedsUSD[DAI] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9; // DAI
        priceFeedsUSD[stkAAVE] = 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9; // AAVE

        // ETH feeds
        priceFeedsETH[WBTC] = 0xdeb288F737066589598e9214E782fa5A8eD689e8; // wBTC
        priceFeedsETH[DAI] = 0x773616E4d11A78F511299002da57A0a94577F1f4; // DAI
        priceFeedsETH[USDC] = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4; // USDC
        priceFeedsETH[USDT] = 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46; // USDT
        priceFeedsETH[stkAAVE] = 0x6Df09E975c830ECae5bd4eD9d90f3A95a4f88012; // AAVE
    }

    /// @notice get price in USD for an asset
    function getPriceUSD(address _asset) public view returns (uint256) {
        return _getPriceUSD(_asset); // 1e18
    }
    /// @notice get price in ETH for an asset
    function getPriceETH(address _asset) public view returns (uint256) {
        return _getPriceETH(_asset); // 1e18
    }
    /// @notice get price in a specific token for an asset
    function getPriceToken(address _asset, address _token) public view returns (uint256) {
        return _getPriceToken(_asset, _token); // 1e(_token.decimals())
    }

    // #### internal
    function _getPriceUSD(address _asset) internal view returns (uint256 price) {
        if (priceFeedsUSD[_asset] != address(0)) {
            price = ChainLinkOracle(priceFeedsUSD[_asset]).latestAnswer().mul(10**10); // scale it to 1e18
        } else if (priceFeedsETH[_asset] != address(0)) {
            price = ChainLinkOracle(priceFeedsETH[_asset]).latestAnswer();
            price = price.mul(ChainLinkOracle(priceFeedsUSD[WETH]).latestAnswer().mul(10**10)).div(ONE_18);
        }
    }
    function _getPriceETH(address _asset) internal view returns (uint256 price) {
        if (priceFeedsETH[_asset] != address(0)) {
            price = ChainLinkOracle(priceFeedsETH[_asset]).latestAnswer();
        }
    }
    function _getPriceToken(address _asset, address _token) internal view returns (uint256 price) {
        uint256 assetUSD = getPriceUSD(_asset);
        uint256 tokenUSD = getPriceUSD(_token);
        if (tokenUSD == 0) {
            return price;
        }
        return assetUSD.mul(10**(uint256(ERC20(_token).decimals()))).div(tokenUSD); // 1e(tokenDecimals)
    }

    // _feed can be address(0) which means disabled
    function updateFeedETH(address _asset, address _feed) external onlyOwner {
        priceFeedsETH[_asset] = _feed;
    }
    function updateFeedUSD(address _asset, address _feed) external onlyOwner {
        priceFeedsUSD[_asset] = _feed;
    }

    /// @notice Contract name
    /// @return bytes32 name
    function getName() override external view returns (bytes32) {
        return "PriceOracle";
    }
}