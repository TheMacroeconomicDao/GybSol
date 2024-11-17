// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Контракт GybernatyUnitManager для управления уровнями пользователей
contract GybernatyUnitManager is ReentrancyGuard {
    // Структура для хранения информации о пользователях
    struct User {
        // Адрес пользователя
        address userAddress;
        // Имя пользователя (опциональное)
        string name;
        // Ссылка пользователя (опциональное)
        string link;
        // Флаг, указывающий, отмечен ли пользователь для повышения уровня
        bool markedUp;
        // Флаг, указывающий, отмечен ли пользователь для понижения уровня
        bool markedDown;
        // Текущий уровень пользователя
        uint32 level;
        // Последнее время вывода токенов Gbr
        uint256 lastWithdrawTime;
        // Счетчик выводов токенов Gbr в текущем месяце
        uint256 withdrawCount;
    }

    // Максимальный уровень пользователя (константа)
    uint32 public constant maxLevel = 4;
    // Количество Gbr токенов, необходимое для вступления в категорию Gybernaty
    uint256 public constant GbrTokenAmount = 1_000_000_000_000;
    // Адрес контракта Gbr токенов
    address public constant GbrTokenAddress = 0xA970cAE9Fa1D7Cca913b7C19DF45BF33d55384A9;
    // Количество BNB, необходимое для вступления в категорию Gybernaty
    uint256 public constant BnbAmount = 1000 ether;

    // Маппинг для хранения информации о пользователях по их адресам
    mapping (address => User) public users;
    // Маппинг для хранения адресов, входящих в категорию Gybernaty
    mapping (address => bool) public gybernaties;

    // События контракта
    event UserMarkUp(address userAddress);
    event UserMarkDown(address userAddress);
    event UserLevelUp(address userAddress);
    event UserLevelDown(address userAddress);
    event GybernatyJoined(address gybernatyAddress);
    event TokensWithdrawn(address userAddress, uint256 amount);
    event UserCreated(address userAddress);

    // Ошибки контракта
    error OnlyGybernaty();
    error LevelInvalid();
    error UserExists();
    error UserNotFound();
    error UserNotMarked();
    error MinLevel();
    error MaxLevel();
    error InsufficientFunds();
    error WithdrawLimitExceeded();
    error InsufficientGbrTokens();

    // Модификатор для проверки, является ли вызывающий адрес членом категории Gybernaty
    modifier onlyGybernaty() {
        if (!gybernaties[msg.sender]) {
            revert OnlyGybernaty();
        }
        _;
    }

    // Конструктор контракта
    constructor() {
        // Контракт не имеет прав только владельца (onlyOwner)
    }

    /**
     * Функция для вступления в категорию Gybernaty
     * @dev Адрес, отправивший достаточное количество Gbr токенов или BNB, становится членом Gybernaty.
     */
    function joinGybernaty() public payable {
        // Проверяем, отправлено ли достаточное количество Gbr токенов или BNB
        if (msg.value < BnbAmount && msg.value < GbrTokenAmount) {
            revert InsufficientFunds();
        }

        // Добавляем адрес в категорию Gybernaty
        gybernaties[msg.sender] = true;

        // Вызываем событие о вступлении в категорию Gybernaty
        emit GybernatyJoined(msg.sender);
    }

    /**
     * Функция для создания нового пользователя
     * @param userAddress Адрес пользователя
     * @param level Начальный уровень пользователя
     * @param name Имя пользователя (опциональное)
     * @param link Ссылка пользователя (опциональное)
     * @dev Только члены Gybernaty могут создавать новых пользователей
     */
    function createUser(address userAddress, uint32 level, string memory name, string memory link) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress != address(0)) {
            revert UserExists();
        }

        // Проверяем, является ли указанный уровень действительным
        if (level < 1 || level > maxLevel) {
            revert LevelInvalid();
        }

        // Создаем нового пользователя
        User memory user = User(
            userAddress,
            name,
            link,
            false,
            false,
            level,
            0,
            0
        );

        // Добавляем пользователя в маппинг
        users[userAddress] = user;

        // Вызываем событие о создании пользователя
        emit UserCreated(userAddress);
    }

    /**
     * Функция для отметки пользователя для повышения уровня
     * @dev Пользователи могут отмечать себя для повышения уровня
     */
    function userMarkUp() public {
        address userAddress = msg.sender;

        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, имеет ли пользователь максимальный уровень
        if (users[userAddress].level == maxLevel) {
            revert MaxLevel();
        }

        // Отмечаем пользователя для повышения уровня
        users[userAddress].markedUp = true;

        // Вызываем событие об отмечке для повышения уровня
        emit UserMarkUp(userAddress);
    }

    /**
     * Функция для отметки пользователя для понижения уровня
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут отмечать пользователей для понижения уровня
     */
    function userMarkDown(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, имеет ли пользователь минимальный уровень
        if (users[userAddress].level == 1) {
            revert MinLevel();
        }

        // Отмечаем пользователя для понижения уровня
        users[userAddress].markedDown = true;

        // Вызываем событие об отмечке для понижения уровня
        emit UserMarkDown(userAddress);
    }

    /**
     * Функция для повышения уровня пользователя
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут повышать уровень пользователей
     */
    function userLevelUp(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, отмечен ли пользователь для повышения уровня
        if (!users[userAddress].markedUp) {
            revert UserNotMarked();
        }

        // Повышаем уровень пользователя
        users[userAddress].level += 1;

        // Сброс отмечек пользователя
        users[userAddress].markedUp = false;
        users[userAddress].markedDown = false;

        // Вызываем событие о повышении уровня
        emit UserLevelUp(userAddress);
    }

    /**
     * Функция для понижения уровня пользователя
     * @param userAddress Адрес пользователя
     * @dev Только члены Gybernaty могут понижать уровень пользователей
     */
    function userLevelDown(address userAddress) public onlyGybernaty {
        // Проверяем, существует ли пользователь
        if (users[userAddress].userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, отмечен ли пользователь для понижения уровня
        if (!users[userAddress].markedDown) {
            revert UserNotMarked();
        }

        // Понижаем уровень пользователя
        users[userAddress].level -= 1;

        // Сброс отмечек пользователя
        users[userAddress].markedUp = false;
        users[userAddress].markedDown = false;

        // Вызываем событие о понижении уровня
        emit UserLevelDown(userAddress);
    }

    /**
     * Функция для вывода токенов Gbr
     * @param amount Количество Gbr токенов для вывода
     * @dev Только пользователи могут выводить токены
     */
    function withdrawGbrTokens(uint256 amount) public nonReentrant {
        address userAddress = msg.sender;
        User storage user = users[userAddress];

        // Проверяем, существует ли пользователь
        if (user.userAddress == address(0)) {
            revert UserNotFound();
        }

        // Проверяем, не превышен ли лимит выводов в текущем месяце
        uint256 currentMonth = block.timestamp / 2629743; // Приближенное количество секунд в месяце
        if (user.lastWithdrawTime / 2629743 != currentMonth || user.withdrawCount >= 2) {
            revert WithdrawLimitExceeded();
        }

        // Проверяем, имеет ли пользователь достаточно токенов Gbr
        if (amount > getMaxWithdrawAmount(user)) {
            revert InsufficientGbrTokens();
        }

        // Обновляем счетчик выводов токенов и время последнего вывода
        user.withdrawCount += 1;
        user.lastWithdrawTime = block.timestamp;

        // Выводим Gbr токены на адрес вызывающего
        payable(userAddress).transfer(amount);

        // Вызываем событие о выводе токенов
        emit TokensWithdrawn(userAddress, amount);
    }

    /**
     * Функция для получения максимального количества токенов, которое пользователь может вывести
     * @param user Адрес пользователя
     * @return Максимальное количество токенов, которое пользователь может вывести
     */
    function getMaxWithdrawAmount(User memory user) public pure returns (uint256) {
        if (user.level == 1) return 1000000000000;
        if (user.level == 2) return 100000000000000;
        if (user.level == 3) return 1000000000000000;
        if (user.level == 4) return 10000000000000000;
        return 0;
    }

    /**
     * Функция для приема Gbr токенов
     * @dev Отклоняет любые другие токены, кроме Gbr токенов
     */
    receive() external payable {
        // Проверяем, является ли отправитель адресом контракта Gbr токенов
        if (msg.sender != GbrTokenAddress) {
            revert(); // Отклонить любые другие токены
        }
    }
}