pragma solidity >=0.5.0;

interface IWTAL {
    function deposit(uint) external returns(bool);
    function withdraw(uint) external returns (bool);
}
