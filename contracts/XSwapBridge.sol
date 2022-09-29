pragma solidity =0.6.6;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import './interfaces/ITaalBridge.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './libraries/SafeMath.sol';
import 'taalswap-core/contracts/interfaces/ITaalPair.sol';
import './libraries/TaalLibrary.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './interfaces/IWTAL.sol';


contract XSwapBridge is ITaalBridge, Ownable {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;
    address public immutable override WTAL;
    address public bridgeOperator;
    address public feeAddress;
    uint public BRIDGE_FEE = 20000000000000000;     // Default 0.02 ETH

    event SwapExactETHForTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event SwapETHForExactTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountOut,
        uint amountInMax,
        address[] pathx
    );
    event SwapTokensForExactETH(
        address indexed to,
        address token,
        uint amount,
        uint amountOut,
        uint amountInMax,
        address[] pathx
    );
    event SwapExactTokensForETH(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event SwapExactTokensForTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event SwapExactTaalForTaal(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event SwapTokensForExactTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountOut,
        uint amountInMax,
        address[] pathx
    );
    event SwapExactTokensForTokensSupportingFeeOnTransferTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event SwapExactETHForTokensSupportingFeeOnTransferTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event SwapExactTokensForETHSupportingFeeOnTransferTokens(
        address indexed to,
        address token,
        uint amount,
        uint amountIn,
        uint amountOutMin,
        address[] pathx
    );
    event XswapExactTokensForTokens(
        address indexed to,
        address indexed token,
        uint indexed amountOut,
        bytes32 txHash
    );
    event XswapExactTaalForTaal(
        address indexed to,
        address indexed token,
        uint indexed amountOut,
        bytes32 txHash
    );
    event XswapTokensForExactTokens(
        address indexed to,
        address token,
        uint amountOut,
        bytes32 txHash
    );
    event XswapTokensForExactETH(
        address indexed to,
        address indexed token,
        uint indexed amountOut,
        bytes32 txHash
    );
    event XswapExactTokensForETH(
        address indexed to,
        address indexed token,
        uint indexed amountOut,
        bytes32 txHash
    );
    event XswapExactTokensForETHSupportingFeeOnTransferTokens(
        address indexed to,
        address indexed token,
        uint indexed amountOut,
        bytes32 txHash
    );
    event XswapExactTokensForTokensSupportingFeeOnTransferTokens(
        address indexed to,
        address indexed token,
        uint indexed amountOut,
        bytes32 txHash
    );

    event  SetBridgeOperator(address indexed _bridge);
    event  SetBridgeFee(uint indexed _fee);
    event  SetFeeAddress(address indexed _feeAddress);

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'XSwapBridge: EXPIRED');
        _;
    }

    modifier limitedAccess() {
        require(msg.sender == bridgeOperator,
            'XSwapBridge: only limited access allowed');
        _;
    }

    constructor(address _factory, address _WETH, address _WTAL, address _bridge) public {
        factory = _factory;
        WETH = _WETH;
        WTAL = _WTAL;
        bridgeOperator = _bridge;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual
    {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = TaalLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? TaalLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ITaalPair(TaalLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
    {
        // Check Bridge Fee
        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // Always TAL is output to intermediate the cross chain swap
        _swap(amounts, path, address(this));
        // Deposit TAL
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amounts[amounts.length - 1]
        );
        // Pay Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactTokensForTokens(to, path[0], amountIn, amounts[amounts.length - 1], amountOutMinX, pathx);
    }
    function xswapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bytes32 txHash
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Always TAL is input in case of cross chain swap
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        // Withdraw TAL
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // Finally the target token of cross chain swap is sent to the owner
        _swap(amounts, path, to);
        emit XswapExactTokensForTokens(to, path[path.length - 1], amounts[amounts.length - 1], txHash);
    }

    function swapExactTaalForTaal(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint[] memory amounts)
    {
        // [ TAL -> Bridge -> Tokens ]
        // Check Bridge Fee
        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        // Deposit TAL
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, WTAL, amountIn
        );
        // Pay for Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactTaalForTaal(to, path[0], amountIn, amountIn, amountOutMinX, pathx);
    }
    function xswapExactTaalForTaal(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bytes32 txHash
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // [ TAL -> Bridge-> TAL ]
        // Withdraw TAL
        TransferHelper.safeTransferFrom(
            path[path.length - 1], WTAL, to, amountIn
        );
        emit XswapExactTaalForTaal(to, path[path.length - 1], amountIn, txHash);
    }

//    // CAUTION : Exact Output of cross chain swap blocked on GUI
//    // This will be not used by cross chain swap
//    // because of price and liquidity changes in the moddle cross chaining.
//    function swapTokensForExactTokens(
//        uint amountOut,
//        uint amountInMax,
//        address[] calldata path,
//        uint amountOutX,
//        address[] calldata pathx,
//        address to,
//        uint deadline
//    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
//    {
//        // Check Bridge Fee
//        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
//        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
//        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
//        TransferHelper.safeTransferFrom(
//            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
//        );
//        // Always TAL is output to intermediate the cross chain swap
//        _swap(amounts, path, address(this));
//        // Deposit TAL
//        TransferHelper.safeTransfer(
//            path[path.length - 1], WTAL, amounts[amounts.length - 1]
//        );
//        // Pay Bridge Fee
//        TransferHelper.safeTransferETH(
//            feeAddress, BRIDGE_FEE
//        );
//        emit SwapTokensForExactTokens(to, path[0], amounts[0], amountOutX, amounts[amounts.length - 1], pathx);
//    }
//    // CAUTION : Exact Output of cross chain swap blocked on GUI
//    // This will be not used by cross chain swap because of 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT'
//    function xswapTokensForExactTokens(
//        uint amountOut,
//        uint amountInMax,       // -> change to amountIn ?
//        address[] calldata path,
//        address to,
//        uint deadline,
//        bytes32 txHash
//    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
//    {
//        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
//        // CAUTION : Because of this line this method will fail on cross chain swap
//        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
//        // Withdraw TAL
//        TransferHelper.safeTransferFrom(
//            path[0], WTAL, address(this), amounts[0]
//        );
//        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
//        TransferHelper.safeTransfer(
//            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
//        );
//        // Finally the target token of cross chain swap is sent to the owner
//        _swap(amounts, path, to);
//        emit XswapTokensForExactTokens(to, path[path.length - 1], amounts[amounts.length - 1], txHash);
//    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
    {
        // Input should be Ether
        require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
        // Check Bridge Fee
        uint amountETH = msg.value.sub(BRIDGE_FEE);
        require(amountETH > 0, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        amounts = TaalLibrary.getAmountsOut(factory, amountETH, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        // Always TAL is output to intermediate the cross chain swap
        _swap(amounts, path, address(this));
        // Deposit TAL
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amounts[amounts.length - 1]
        );
        // Pay Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactETHForTokens(to, path[0], msg.value, amounts[amounts.length - 1], amountOutMinX, pathx);
        // --> bridge will call xswapExactTokensForTokens
    }

//    // CAUTION : Exact Output of cross chain swap blocked on GUI
//    // This will be not used by cross chain swap
//    // because of price and liquidity changes in the moddle cross chaining.
//    function swapTokensForExactETH(
//        uint amountOut,
//        uint amountInMax,
//        address[] calldata path,
//        uint amountOutX,
//        address[] calldata pathx,
//        address to,
//        uint deadline
//    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
//    {
//        // Check Bridge Fee
//        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
//        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
//        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
//        TransferHelper.safeTransferFrom(
//            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
//        );
//        // Always TAL is output to intermediate the cross chain swap
//        _swap(amounts, path, address(this));
//        // Deposit TAL
//        TransferHelper.safeTransfer(
//            path[path.length - 1], WTAL, amounts[amounts.length - 1]
//        );
//        // Pay Bridge Fee
//        TransferHelper.safeTransferETH(
//            feeAddress, BRIDGE_FEE
//        );
//        emit SwapTokensForExactETH(to, path[0], amounts[0], amountOutX, amounts[amounts.length - 1], pathx);
//    }
//    // CAUTION : Exact Output of cross chain swap blocked on GUI
//    // This will be not used by cross chain swap because of 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT'
//    function xswapTokensForExactETH(
//        uint amountOut,
//        uint amountInMax,       // -> change to amountIn ?
//        address[] calldata path,
//        address to,
//        uint deadline,
//        bytes32 txHash
//    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
//    {
//        // Output should be Ether
//        require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
//        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
//        // CAUTION : Because of this line this method will fail on cross chain swap
//        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
//        // Withdraw TAL
//        TransferHelper.safeTransferFrom(
//            path[0], WTAL, address(this), amounts[0]
//        );
//        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
//        TransferHelper.safeTransfer(
//            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
//        );
//        _swap(amounts, path, address(this));
//        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
//        // Finally the target token of cross chain swap is sent to the owner
//        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
//        emit XswapTokensForExactETH(to, path[path.length - 1], amounts[amounts.length - 1], txHash);
//    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
    {
        // Check Bridge Fee
        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // Always TAL is output to intermediate the cross chain swap
        _swap(amounts, path, address(this));
        // Deposit TAL
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amounts[amounts.length - 1]
        );
        // Pay Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactTokensForETH(to, path[0], amountIn, amounts[amounts.length - 1], amountOutMinX, pathx);
    }
    function xswapExactTokensForETH(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline,
    bytes32 txHash
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Output should be Ether
    require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
    amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        // Withdraw TAL
    TransferHelper.safeTransferFrom(
    path[0], WTAL, address(this), amounts[0]
    );
    require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
    TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        // Finally the target token of cross chain swap is sent to the owner
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        emit XswapExactTokensForETH(to, path[path.length - 1], amounts[amounts.length - 1], txHash);
    }

//    // CAUTION : Exact Output of cross chain swap blocked on GUI
//    // This will be not used by cross chain swap
//    // because of price and liquidity changes in the moddle cross chaining.
//    function swapETHForExactTokens(
//        uint amountOut,
//        address[] calldata path,
//        uint amountOutX,
//        address[] calldata pathx,
//        address to,
//        uint deadline
//    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
//    {
//        // Input should be Ether
//        require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
//        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
//        // Check Bridge Fee
//        uint amountETH = msg.value.sub(BRIDGE_FEE);
//        require(amountETH > 0, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
//        require(amounts[0] <= amountETH, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
//        IWETH(WETH).deposit{value: amounts[0]}();
//        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
//        // Always TAL is output to intermediate the cross chain swap
//        _swap(amounts, path, address(this));
//        // Deposit TAL
//        TransferHelper.safeTransfer(
//            path[path.length - 1], WTAL, amounts[amounts.length - 1]
//        );
//        // Pay Bridge Fee
//        TransferHelper.safeTransferETH(
//            feeAddress, BRIDGE_FEE
//        );
//        // Refund dust eth, if any
//        if (msg.value.sub(BRIDGE_FEE) > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value.sub(BRIDGE_FEE).sub(amounts[0]));
//        emit SwapETHForExactTokens(to, path[0], amounts[0], amountOutX, amounts[amounts.length - 1], pathx);
//        // --> Bridge will call xswapTokensForExactTokens
//    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = TaalLibrary.sortTokens(input, output);
            ITaalPair pair = ITaalPair(TaalLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = TaalLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? TaalLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline)
    {
        // Check Bridge Fee
        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        // Always TAL is output to intermediate the cross chain swap
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(
            amountOut >= amountOutMin,
            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        // Deposit TAL
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        // Pay Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactTokensForTokensSupportingFeeOnTransferTokens(to, path[0], amountIn, amountOut, amountOutMinX, pathx);
    }
    function xswapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bytes32 txHash
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts) {
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        // Withdraw TAL
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        // Finally the target token of cross chain swap is sent to the owner
        _swapSupportingFeeOnTransferTokens(path, to);
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore);
        emit XswapExactTokensForTokensSupportingFeeOnTransferTokens(to, path[path.length - 1], amountOut, txHash);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline)
    {
        // Input should be Ether
        require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
        // Check Bridge Fee
        uint amountIn = msg.value.sub(BRIDGE_FEE);
        require(amountIn > 0, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        // Always TAL is output to intermediate the cross chain swap
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(
            amountOut >= amountOutMin,
            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        // Deposit TAL
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        // Pay for Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactETHForTokensSupportingFeeOnTransferTokens(to, path[0], msg.value, amountOut, amountOutMinX, pathx);
        // --> Bridge will call xswapExactTokensForTokensSupportingFeeOnTransferTokens
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline)
    {
        // Output should be Ether
        require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
        // Check Bridge Fee
        require(msg.value >= BRIDGE_FEE, 'XSwapBridge: INSUFFICIENT_BRIDGE_FEE');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        // Always TAL is output to intermediate the cross chain swap
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(
            amountOut >= amountOutMin,
            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        // Deposit TAL
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        // Pay Bridge Fee
        TransferHelper.safeTransferETH(
            feeAddress, BRIDGE_FEE
        );
        emit SwapExactTokensForETHSupportingFeeOnTransferTokens(to, path[0], amountIn, amountOut, amountOutMinX, pathx);
    }
    function xswapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline,
        bytes32 txHash
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Output should be Ether
        require(path[path.length - 1] == WETH, 'TaalRouter: INVALID_PATH');
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        // Withdraw TAL
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(amountOut);
        // Finally the target token of cross chain swap is sent to the owner
        TransferHelper.safeTransferETH(to, amountOut);
        emit XswapExactTokensForETHSupportingFeeOnTransferTokens(to, path[path.length - 1], amountOut, txHash);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual override returns (uint amountB)
    {
        return TaalLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountOut)
    {
        return TaalLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual override returns (uint amountIn)
    {
        return TaalLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts)
    {
        return TaalLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) public view virtual override returns (uint[] memory amounts)
    {
        return TaalLibrary.getAmountsIn(factory, amountOut, path);
    }

    function setBridgeOperator(address _bridge) public onlyOwner {
        bridgeOperator = _bridge;
        emit SetBridgeOperator(_bridge);
    }

    function setBridgeFee(uint _fee) public onlyOwner {
        BRIDGE_FEE = _fee;
        emit SetBridgeFee(_fee);
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
        emit SetFeeAddress(_feeAddress);
    }
}
