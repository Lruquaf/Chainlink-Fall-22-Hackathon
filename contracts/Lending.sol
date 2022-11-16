// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Lending is Ownable, ReentrancyGuard {
    event Borrowed(
        uint256 id,
        address borrower,
        uint256 collateralAmount,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 loanDeadline,
        bool isActive
    );
    event Repaid(
        uint256 id,
        address borrower,
        uint256 collateralAmount,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 loanDeadline,
        bool isActive
    );
    event Withdrew(
        uint256 id,
        address borrower,
        uint256 loanDeadline,
        uint256 collateralAmount,
        bool isActive
    );
    event Deposited(uint256 amount, uint256 depositTime, uint256 reserve);

    struct Loan {
        uint256 loanId; // Id of loan
        address borrower; // Address who get the loan
        uint256 interestRate; // Interest rate of current loan
        uint256 collateralAmount; // Amount value in collateral token
        uint256 collateralAmountInUSDT; // Amount value in USDT
        uint256 loanAmount; // Loan amount in USDT
        uint256 loanStartingTime; // Loan starting time
        uint256 loanDuration; // Loan term
        uint256 loanEndingTime; // Deadline to repay the loan
        LOAN_STATE loanState; // Status of loan (none, borrowed, repaid, failed)
    }

    AggregatorV3Interface public priceFeed;
    IERC20 public USDTtoken;
    IERC20 public LINKtoken;

    uint256 public interestRate;

    uint256 public idCounter;

    enum LOAN_STATE {
        NONE,
        BORROWED,
        REPAID,
        FAILED
    }

    uint256 public USDTReserve; // USDT reserve of the contrect

    mapping(uint256 => Loan) loans; // Mapping of ids to loans

    constructor(
        address _USDTtoken,
        address _LINKtoken,
        address _priceFeed
    ) {
        USDTtoken = IERC20(_USDTtoken);
        LINKtoken = IERC20(_LINKtoken);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // This function is called by borrower to get the loan.

    function borrow(uint256 _loanAmount) public nonReentrant {
        require(_loanAmount <= USDTReserve, "Not enough reserve USDT to lend!");
        Loan memory loan;
        loan.loanId = idCounter;
        loan.borrower = msg.sender;
        loan.interestRate = interestRate;
        (
            loan.collateralAmount,
            loan.collateralAmountInUSDT
        ) = getCollateralAmount(_loanAmount, loan.interestRate);

        loan.loanAmount = _loanAmount;
        loan.loanStartingTime = block.timestamp;
        loan.loanEndingTime = block.timestamp + loan.loanDuration;
        loan.loanState = LOAN_STATE.BORROWED;
        loans[idCounter] = loan;
        require(
            LINKtoken.transferFrom(
                loan.borrower,
                address(this),
                loan.collateralAmount
            ),
            "Not enough collateral!"
        );
        require(
            USDTtoken.transfer(loan.borrower, loan.loanAmount),
            "Transfer failed!"
        );
        emit Borrowed(
            idCounter,
            msg.sender,
            loan.collateralAmount,
            _loanAmount,
            loan.interestRate,
            loan.loanEndingTime,
            true
        );
        idCounter++;
    }

    // This function is called by an address who borrowed with this id
    // to repay before its deadline.

    function repay(uint256 _id) public checkStatus(_id) nonReentrant {
        checkLoanDeadline(_id);
        require(
            loans[_id].loanState == LOAN_STATE.FAILED,
            "The loan with this id was not paid before its deadline!"
        );
        require(
            USDTtoken.transferFrom(
                msg.sender,
                address(this),
                loans[_id].collateralAmountInUSDT
            ),
            "Repay was failed!"
        );
        loans[_id].loanState = LOAN_STATE.REPAID;
        require(LINKtoken.transfer(msg.sender, loans[_id].collateralAmount));
        emit Repaid(
            _id,
            msg.sender,
            loans[_id].collateralAmount,
            loans[_id].collateralAmountInUSDT,
            loans[_id].interestRate,
            loans[_id].loanEndingTime,
            false
        );
    }

    function setInterestRate(uint256 _rate) public onlyOwner {
        interestRate = _rate;
    }

    function getExchangeRate() internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getCollateralAmount(uint256 _loanAmount, uint256 _interestRate)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 collateralAmountInUSDT = ((_interestRate / 100) * _loanAmount) +
            _loanAmount;
        uint256 collateralAmount = (1 / getExchangeRate()) *
            collateralAmountInUSDT;
        return (collateralAmount, collateralAmountInUSDT);
    }

    // This function checks each time whether the loan has expired. If the period has expired,
    // the collateral is transferred from the contract to the contract owner.

    function checkLoanDeadline(uint256 _id) internal {
        if (loans[_id].loanEndingTime <= block.timestamp) {
            loans[_id].loanState = LOAN_STATE.FAILED;
            payable(owner()).transfer(loans[_id].collateralAmount);
            emit Withdrew(
                _id,
                loans[_id].borrower,
                loans[_id].loanEndingTime,
                loans[_id].collateralAmount,
                false
            );
        }
    }

    // The contract holder uses this function to provide USDT liquidity to the contract.

    function deposit(uint256 _amount) public onlyOwner {
        USDTtoken.transferFrom(msg.sender, address(this), _amount);
        USDTReserve += _amount;
        emit Deposited(_amount, block.timestamp, USDTReserve);
    }

    modifier checkStatus(uint256 _id) {
        require(
            loans[_id].loanState == LOAN_STATE.NONE,
            "The loan with this id does not exist!"
        );
        require(
            loans[_id].loanState == LOAN_STATE.REPAID,
            "The loan with this id was already paid!"
        );
        _;
    }
}
