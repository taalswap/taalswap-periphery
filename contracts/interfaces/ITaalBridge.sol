pragma solidity >=0.6.2;

interface ITaalBridge {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function WTAL() external pure returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

//    function swapTokensForExactTokens(
//        uint amountOut,
//        uint amountInMax,
//        address[] calldata path,
//        uint amountOutX,
//        address[] calldata pathx,
//        address to,
//        uint deadline
//    ) external payable returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

//    function swapTokensForExactETH(
//        uint amountOut,
//        uint amountInMax,
//        address[] calldata path,
//        uint amountOutX,
//        address[] calldata pathx,
//        address to,
//        uint deadline
//    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

//    function swapETHForExactTokens(
//        uint amountOut,
//        address[] calldata path,
//        uint amountOutX,
//        address[] calldata pathx,
//        address to,
//        uint deadline
//    ) external payable returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external payable;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external payable;
}
