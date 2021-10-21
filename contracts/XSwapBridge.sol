pragma solidity =0.6.6;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import './interfaces/ITaalBridge.sol';
import './libraries/SafeMath.sol';
import 'taalswap-core/contracts/interfaces/ITaalPair.sol';
import './libraries/TaalLibrary.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';
import './interfaces/IWTAL.sol';

contract XSwapBridge is ITaalBridge {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;
    address public immutable override WTAL;
    address public immutable bridgeOperator;

    event SwapExactETHForTokens(        // -> xswapExactTokensForTokens
        address indexed to,
        uint indexed amountIn,
        uint indexed amountOutMin,
        address[] pathx
    );
    event SwapETHForExactTokens(        // -> xswapTokensForExactTokens
        address indexed to,
        uint indexed amountOut,
        uint indexed amountInMax,
        address[] pathx
    );
    event SwapTokensForExactETH(        // -> x
        address indexed to,
        uint indexed amountOut,
        uint indexed amountInMax,
        address[] pathx
    );
    event SwapExactTokensForETH(        // -> x
        address indexed to,
        uint indexed amountIn,
        uint indexed amountOutMin,
        address[] pathx
    );
    event SwapExactTokensForTokens(     // -> x
        address indexed to,
        uint indexed amountIn,
        uint indexed amountOutMin,
        address[] pathx
    );
    event SwapTokensForExactTokens(     // -> x
        address indexed to,
        uint indexed amountOut,
        uint indexed amountInMax,
        address[] pathx
    );
    event SwapExactTokensForTokensSupportingFeeOnTransferTokens(        // -> xswapExactTokensForTokens
        address indexed to,
        uint indexed amountIn,
        uint indexed amountOutMin,
        address[] pathx
    );
    event SwapExactETHForTokensSupportingFeeOnTransferTokens(           // -> xswapExactTokensForTokens
        address indexed to,
        uint indexed amountIn,
        uint indexed amountOutMin,
        address[] pathx
    );
    event SwapExactTokensForETHSupportingFeeOnTransferTokens(           // -< swapExactTokensForETH
        address indexed to,
        uint indexed amountIn,
        uint indexed amountOutMin,
        address[] pathx
    );

    event  SetBridge(address indexed _bridge);

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
    ) external virtual override ensure(deadline) returns (uint[] memory amounts)
    {
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // _swap(amounts, path, to);
        _swap(amounts, path, address(this));
        uint amountOut = amounts[amounts.length - 1];
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[0], WTAL, amounts[0]
        );
        emit SwapExactTokensForTokens(to, amountOut, amountOutMinX, pathx);
    }
    function xswapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Always TAL is input
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint amountOutX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts)
    {
        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        // _swap(amounts, path, to);
        _swap(amounts, path, address(this));
        uint amountOutRlt = amounts[amounts.length - 1];
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOutRlt
        );
        emit SwapTokensForExactTokens(to, amountOutX, amountOutRlt, pathx);
    }
    function xswapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Always TAL is input
        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
        amounts = TaalLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        // _swap(amounts, path, to);
        _swap(amounts, path, address(this));
        uint amountOut = amounts[amounts.length - 1];
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        emit SwapExactETHForTokens(to, amountOut, amountOutMinX, pathx);
        // => xswapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        uint amountOutX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts)
    {
        // require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        // IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        // TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        uint amountOutRlt = amounts[amounts.length - 1];
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOutRlt);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOutRlt
        );
        emit SwapTokensForExactETH(to, amountOutX, amountOutRlt, pathx);
    }
    function xswapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Always TAL is input
        require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts)
    {
        // require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        // IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        // TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        uint amountOut = amounts[amounts.length - 1];
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        emit SwapExactTokensForETH(to, amountOut, amountOutMinX, pathx);
    }
    function xswapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) limitedAccess returns (uint[] memory amounts)
    {
        // Always TAL is input
        // require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
        amounts = TaalLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], WTAL, address(this), amounts[0]
        );
        require(IERC20(path[0]).balanceOf(address(this)) >= amounts[0], 'XSwapBridge: WTAL_WITHDRAW_FAILED');
        TransferHelper.safeTransfer(
            path[0], TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        uint amountOutX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
        amounts = TaalLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'XSwapBridge: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        // _swap(amounts, path, to);
        _swap(amounts, path, address(this));
        uint amountOutRlt = amounts[amounts.length - 1];
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOutRlt);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOutRlt
        );
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
        emit SwapETHForExactTokens(to, amountOutX, amountOutRlt, pathx);
        // => xswapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) internal virtual
    {
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
    ) external virtual override ensure(deadline)
    {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        // uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        // _swapSupportingFeeOnTransferTokens(path, to);
        // require(
        //    IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
        //    'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        //);
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(
            amountOut >= amountOutMin,
            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[0], WTAL, amountOut
        );
        emit SwapExactTokensForTokensSupportingFeeOnTransferTokens(to, amountOut, amountOutMinX, pathx);
        // => xswapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    }
//    function xswapExactTokensForTokensSupportingFeeOnTransferTokens(
//        uint amountIn,
//        uint amountOutMin,
//        address[] calldata path,
//        address to,
//        uint deadline
//    ) external virtual limitedAccess ensure(deadline)
//    {
//        // Always TAL is input
//        TransferHelper.safeTransferFrom(
//            path[0], WTAL, address(this), amountIn
//        );
//        // TransferHelper.safeTransferFrom(
//        //     path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amountIn
//        // );
//        TransferHelper.safeTransferFrom(
//            path[0], address(this), TaalLibrary.pairFor(factory, path[0], path[1]), amountIn
//        );
//        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
//        _swapSupportingFeeOnTransferTokens(path, to);
//        require(
//            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
//            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
//        );
//    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline)
    {
        // Always TAL out
        require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amountIn));
        // uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        // _swapSupportingFeeOnTransferTokens(path, to);
        // uint amountOut = IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore);
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(
            amountOut >= amountOutMin,
            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        emit SwapExactETHForTokensSupportingFeeOnTransferTokens(to, amountOut, amountOutMinX, pathx);
        // => xswapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    }
//    function xswapExactETHForTokensSupportingFeeOnTransferTokens(
//        uint amountOutMin,
//        address[] calldata path,
//        address to,
//        uint deadline
//    ) external virtual limitedAccess ensure(deadline)
//    {
//        // Always TAL is input
//        TransferHelper.safeTransferFrom(
//            path[0], WTAL, address(this), amountIn
//        );
//        // require(path[0] == WETH, 'XSwapBridge: INVALID_PATH');
//        uint amountIn = msg.value;
//        IWETH(WETH).deposit{value: amountIn}();
//        assert(IWETH(WETH).transfer(TaalLibrary.pairFor(factory, path[0], path[1]), amountIn));
//        // uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
//        // _swapSupportingFeeOnTransferTokens(path, to);
//        // uint amountOut = IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore);
//        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
//        _swapSupportingFeeOnTransferTokens(path, address(this));
//        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
//        require(
//            amountOut >= amountOutMin,
//            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
//        );
//        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
//        TransferHelper.safeTransfer(
//            path[path.length - 1], WTAL, amountOut
//        );
//    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint amountOutMinX,
        address[] calldata pathx,
        address to,
        uint deadline
    ) external virtual override ensure(deadline)
    {
        // Always TAL out
        require(path[path.length - 1] == WETH, 'XSwapBridge: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, TaalLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        // _swapSupportingFeeOnTransferTokens(path, address(this));
        // uint amountOut = IERC20(WETH).balanceOf(address(this));
        // require(amountOut >= amountOutMin, 'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT');
        // IWETH(WETH).withdraw(amountOut);
        // TransferHelper.safeTransferETH(to, amountOut);
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(address(this));
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(path[path.length - 1]).balanceOf(address(this)).sub(balanceBefore);
        require(
            amountOut >= amountOutMin,
            'XSwapBridge: INSUFFICIENT_OUTPUT_AMOUNT'
        );
        // IERC20(path[path.length - 1]).transfer(WTAL, amountOut);
        TransferHelper.safeTransfer(
            path[path.length - 1], WTAL, amountOut
        );
        emit SwapExactTokensForETHSupportingFeeOnTransferTokens(to, amountOut, amountOutMinX, pathx);
        // => xswapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
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

//    function setBridgeOp(address _bridge) public onlyOwner {
//        bridgeOperator = _bridge;
//        emit SetBridge(_bridge);
//    }
}
