--[[
-- TriviaBot Version 1.0
--]]

-- Global Variables

-- Declared colour codes for console messages
local RED     = "|cffff0000";
local MAGENTA = "|cffff00ff";
local WHITE   = "|cffffffff";


TRIVIA_VERSION = "1.0" -- Version number

-- Run-time variables
TRIVIA_RUNNING = false;
TRIVIA_ACCEPT_ANSWERS = false;
TRIVIA_LOADED = false;
TRIVIA_NEW_CHANNEL = "none"; -- For changing channels
TRIVIA_ACTIVE_QUESTION = 0; -- The currently active question
TRIVIA_REPORT_COUNTER = 0;
TRIVIA_ROUND_COUNTER = 0; -- Count for which question we're on in a round
TRIVIA_QUESTION_ORDER = {}; -- An array to store in which order the questions will be asked
TRIVIA_QUESTION_STARTTIME = 0; -- When the question was started
TRIVIA_TIME_RECORD = {}; -- Records the quickest time
TRIVIA_SCORES = {}; -- The scores table
TRIVIA_SCHEDULE = {}; -- The array used for scheduling events

-- Configuration Variables
TRIVIA_CONFIG = {};

-- Other
INVALID_COMMAND = RED .. "Invalid Command Entered. " .. WHITE .. "Try '/trivia help'";

-- Reset Config function
function Trivia_ResetConfig()

	if (not TRIVIA_CONFIG.CHANNEL_TYPE) then
		TRIVIA_CONFIG.CHANNEL_TYPE = "private"; -- The default used (Private Channel)
	end
	
	if (not TRIVIA_CONFIG.CHANNEL) then
		TRIVIA_CONFIG.CHANNEL = "TriviaChannel"; -- The default private channel
	end
	
	if (not TRIVIA_CONFIG.ROUND_SIZE) then
		TRIVIA_CONFIG.ROUND_SIZE = 0; -- Defaults to unlimited questions per round
	end
			
	if (not TRIVIA_CONFIG.QLIST) then
		TRIVIA_CONFIG.QLIST = "wow"; -- Default question list
	end
	
	if (not TRIVIA_CONFIG.UPDATEINTERVAL) then
		TRIVIA_CONFIG.UPDATEINTERVAL = 0.5; -- Default Update interval. Tweaking may increase performance.
	end
	
	if (not TRIVIA_CONFIG.INTERVAL) then
		TRIVIA_CONFIG.INTERVAL = 10; -- Number of seconds between questions
	end
	
	if (not TRIVIA_CONFIG.REPORT_INTERVAL) then
		TRIVIA_CONFIG.REPORT_INTERVAL = 5; -- Defaults to reporting scores every 5 answers
	end
	
	if (not TRIVIA_CONFIG.SHOW_REPORTS) then
		TRIVIA_CONFIG.SHOW_REPORTS = true; -- Show reports
	end
	
	if (not TRIVIA_CONFIG.SHOW_ANSWERS) then
		TRIVIA_CONFIG.SHOW_ANSWERS = true; -- Show Answers
	end
	
	if (not TRIVIA_CONFIG.QUESTION_TIMEOUT) then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 45; -- Default question timeout
	end
	
	if (not TRIVIA_CONFIG.QUESTION_TIMEWARN) then
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 20; -- Default warning at 20 seconds.
	end
	
	if (not TRIVIA_CONFIG.GUIENABLED) then
		TRIVIA_CONFIG.GUIENABLED = true; -- GUI is on by default
	end
	
	-- Store the version
	TRIVIA_CONFIG.CONFIG_VERSION = TRIVIA_VERSION;

end

-- Load Function
function Trivia_OnLoad()
	-- Register Events
	this:RegisterEvent("CHAT_MSG_CHANNEL");    
	this:RegisterEvent("CHAT_MSG_RAID");
	this:RegisterEvent("CHAT_MSG_RAID_LEADER");	
	this:RegisterEvent("CHAT_MSG_SAY");		
	this:RegisterEvent("CHAT_MSG_YELL");		
	this:RegisterEvent("CHAT_MSG_PARTY");		
	this:RegisterEvent("CHAT_MSG_GUILD");
	this:RegisterEvent("CHAT_MSG_SYSTEM");
	this:RegisterEvent("ADDON_LOADED");

    --Register Slash Command
    SLASH_TRIVIA1 = "/trivia";
	SLASH_TRIVIA2 = "/triviabot";
    SlashCmdList["TRIVIA"] = Trivia_Command;
	
	-- Initialise the Chat Select DropdownBox
	UIDropDownMenu_JustifyText("LEFT", TriviaGUIChatSelect);
	UIDropDownMenu_Initialize(TriviaGUIChatSelect, TriviaGUIChatSelect_Initialize);
	
	-- Initialise the Qlist Select DropdownBox
	UIDropDownMenu_JustifyText("LEFT", TriviaGUIQListSelect);
	UIDropDownMenu_Initialize(TriviaGUIQListSelect, TriviaGUIQListSelect_Initialize);
	
	-- Initialise the Timeout Select DropdownBox
	UIDropDownMenu_JustifyText("LEFT", TriviaGUITimeoutSelect);
	UIDropDownMenu_Initialize(TriviaGUITimeoutSelect, TriviaGUITimeoutSelect_Initialize);
	
	-- Initialise the Interval Select DropdownBox
	UIDropDownMenu_JustifyText("LEFT", TriviaGUIIntervalSelect);
	UIDropDownMenu_Initialize(TriviaGUIIntervalSelect, TriviaGUIIntervalSelect_Initialize);
	
	-- Initialise the RoundSize Select DropdownBox
	UIDropDownMenu_JustifyText("LEFT", TriviaGUIRoundSizeSelect);
	UIDropDownMenu_Initialize(TriviaGUIRoundSizeSelect, TriviaGUIRoundSizeSelect_Initialize);

	
	-- Disable the Skip Question button
	TriviaGUISkipButton:Disable();

end

function Trivia_OnUpdate(elapsed)
	-- OnUpdate
	this.TimeSinceLastUpdate = this.TimeSinceLastUpdate + elapsed; 	

	if (this.TimeSinceLastUpdate > TRIVIA_CONFIG.UPDATEINTERVAL) then
		Trivia_DoSchedule();
		this.TimeSinceLastUpdate = 0;
	end
end


-- Slash Command
function Trivia_Command(cmd)

	-- Convert to lower case
	cmd = string.lower(cmd);

	local msgArgs = {};
	local numArgs = 0;

	-- Search for seperators in the string and return
	-- the separated data.
	for value in string.gmatch(cmd, "[^ ]+") do
		numArgs = numArgs + 1;
		msgArgs[numArgs] = value;
	end -- end for
	
	-- Get the number of arguments
	--numArgs = table.getn(msgArgs);
    
	if (numArgs == 0) then
		-- Show the GUI
		if (not TRIVIA_CONFIG.GUIENABLED) then
			TriviaGUI:Show();
			TRIVIA_CONFIG.GUIENABLED = true;
		else
			TriviaGUI:Hide();
			TRIVIA_CONFIG.GUIENABLED = false;
		end
        
	elseif (numArgs == 1) then
		if (msgArgs[1] == "skip") then
			Trivia_SkipQuestion();
		elseif (msgArgs[1] == "shuffle") then
			-- Restart and reshuffle the questions
			Trivia_ConsoleMessage("Questions shuffled");
			Trivia_Shuffle();
		elseif (msgArgs[1] == "stop") then
			-- Stop the bot
			if (TRIVIA_RUNNING) then
				Trivia_Stop();
			else
				Trivia_ErrorMessage("No game running!");
			end
		elseif (msgArgs[1] == "qlist") then
			Trivia_ConsoleMessage("Select question list: ");
			Trivia_ConsoleMessage("normal - Mixed questions.");
			Trivia_ConsoleMessage("wow - World of Warcraft questions.")
			Trivia_ConsoleMessage("turtle - Server specific questions.")
			Trivia_ConsoleMessage("geography - Geography questions.")
		elseif (msgArgs[1] == "clear") then
			-- Clear the scores
			if (TRIVIA_RUNNING) then
				Trivia_SendMessage("Scores cleared.");
			end
			
			TRIVIA_SCORES = {};
			TRIVIA_TIME_RECORD = {["time"] = TRIVIA_CONFIG.QUESTION_TIMEOUT + 1, ["holder"] = "noone"};
			Trivia_ConsoleMessage("Scores cleared.");
			
		elseif (msgArgs[1] == "start") then
			-- Start the bot
			if (not TRIVIA_RUNNING) then
				Trivia_Start();
			else
				Trivia_ErrorMessage("Game is already running!");
			end
		elseif (msgArgs[1] == "help") then
			Trivia_Help();
		elseif (msgArgs[1] == "channel") then
			-- Produce an error
			Trivia_ErrorMessage("Usage: /trivia channel <channel name>");
			Trivia_ConsoleMessage("Try SAY | PARTY | RAID | GUILD | <custom channel>");
			Trivia_ConsoleMessage("Example: /trivia channel RAID");
			Trivia_ConsoleMessage("Example: /trivia channel Trivia");
		else
			Trivia_ErrorMessage("Invalid Command - Try '/trivia help'");
		end
	elseif ((numArgs == 2) and (msgArgs[1] ~= "answer")) then
		if (msgArgs[1] == "channel") then
			if (msgArgs[2] == "say") then
				Trivia_ConsoleMessage(RED .. "WARNING: " .. WHITE .. "Say Selected");
				Trivia_ConsoleMessage("Outputting questions to 'say' can be very annoying in busy areas");
				Trivia_ConsoleMessage("If people report you, your account may be suspended for spamming");
				Trivia_ConsoleMessage("Only use 'say' in quiet and/or instanced areas");
				Trivia_ChannelSelect(msgArgs[2]);
			elseif (msgArgs[2] == "party" or msgArgs[2] == "raid" or msgArgs[2] == "guild") then
					Trivia_ChannelSelect(msgArgs[2]);
			else
				-- Joining a new private channel
				Trivia_ChannelSelect("private", msgArgs[2]); 
			end
		elseif (msgArgs[1] == "qlist") then
			Trivia_QlistSelect(msgArgs[2]);
		else
			Trivia_ErrorMessage("Invalid Command - Try '/trivia help'");
		end
	elseif (msgArgs[1] == "answer") then
		-- Console answer
		if (not msgArgs[2]) then
			Trivia_ErrorMessage("Include your answer" );
		else
			local answer = msgArgs[2];
			-- Concatenate Answer
			for i=3, numArgs, 1 do
				answer = answer .. " " .. msgArgs[i];
			end
			
			-- Check the answer
			Trivia_CheckAnswer("CONSOLE PLAYER", answer);
		end
	else
		Trivia_ErrorMessage("Invalid Command - Try '/trivia help'" );
	end

end
	
-- Event Handler
function Trivia_OnEvent(event)

	if (event == "ADDON_LOADED") then
		if (not TRIVIA_LOADED) then
		
			-- Load the saved variables
			if (not TRIVIA_CONFIG.CONFIG_VERSION) then
				Trivia_ConsoleMessage("First Run detected - Resetting Configuration");
				Trivia_ResetConfig();
			end
			
			if (TRIVIA_CONFIG.CONFIG_VERSION ~= TRIVIA_VERSION) then
				Trivia_ConsoleMessage("Updated Version detected - Resetting Configuration");
				Trivia_ConsoleMessage("Old: " .. TRIVIA_CONFIG.CONFIG_VERSION .. " New: " .. TRIVIA_VERSION);
				Trivia_ResetConfig();
			end
			
			--Start in the 'off' state
			TRIVIA_ACCEPT_ANSWERS = false;
			
			-- Send a message
			Trivia_ConsoleMessage("Version " .. TRIVIA_VERSION .. " loaded.");
			
			-- Update the GUI with the current configuration
			Trivia_GUIUpdate();
						
			-- Auto-Join the channel (probably annoying, so disabled)
			--if (GetChannelName(TRIVIA_CONFIG.CHANNEL) <= 0) then
				--TRIVIA_NEW_CHANNEL = TRIVIA_CONFIG.CHANNEL;
				--Trivia_ChangeChannel();
			--end
		
			-- Load the questions
			
			if (TRIVIA_CONFIG.QLIST == "normal") then
				TRIVIA_QUESTIONS = NORMAL_TRIVIA_QUESTIONS;
				TRIVIA_ANSWERS1 = NORMAL_TRIVIA_ANSWERS1;
				TRIVIA_ANSWERS2 = NORMAL_TRIVIA_ANSWERS2;
				TRIVIA_ANSWERS3 = NORMAL_TRIVIA_ANSWERS3;
				TRIVIA_ANSWERS4 = NORMAL_TRIVIA_ANSWERS4;
				TRIVIA_ANSWERS5 = NORMAL_TRIVIA_ANSWERS5;
				TRIVIA_ANSWERS6 = NORMAL_TRIVIA_ANSWERS6;	
				TRIVIA_ANSWERS7 = NORMAL_TRIVIA_ANSWERS7;
				TRIVIA_ANSWERS8 = NORMAL_TRIVIA_ANSWERS8;
			elseif (TRIVIA_CONFIG.QLIST == "wow") then
				TRIVIA_QUESTIONS = WOW_TRIVIA_QUESTIONS;
				TRIVIA_ANSWERS1 = WOW_TRIVIA_ANSWERS1;
				TRIVIA_ANSWERS2 = WOW_TRIVIA_ANSWERS2;
				TRIVIA_ANSWERS3 = WOW_TRIVIA_ANSWERS3;
				TRIVIA_ANSWERS4 = WOW_TRIVIA_ANSWERS4;
				TRIVIA_ANSWERS5 = WOW_TRIVIA_ANSWERS5;
				TRIVIA_ANSWERS6 = WOW_TRIVIA_ANSWERS6;
				TRIVIA_ANSWERS7 = WOW_TRIVIA_ANSWERS7;
				TRIVIA_ANSWERS8 = WOW_TRIVIA_ANSWERS8;
			elseif (TRIVIA_CONFIG.QLIST == "turtle") then
				TRIVIA_QUESTIONS = TURTLE_TRIVIA_QUESTIONS;
				TRIVIA_ANSWERS1 = TURTLE_TRIVIA_ANSWERS1;
				TRIVIA_ANSWERS2 = TURTLE_TRIVIA_ANSWERS2;
				TRIVIA_ANSWERS3 = TURTLE_TRIVIA_ANSWERS3;
				TRIVIA_ANSWERS4 = TURTLE_TRIVIA_ANSWERS4;
				TRIVIA_ANSWERS5 = TURTLE_TRIVIA_ANSWERS5;
				TRIVIA_ANSWERS6 = TURTLE_TRIVIA_ANSWERS6;
				TRIVIA_ANSWERS7 = TURTLE_TRIVIA_ANSWERS7;
				TRIVIA_ANSWERS8 = TURTLE_TRIVIA_ANSWERS8;
			elseif (TRIVIA_CONFIG.QLIST == "geography") then
				TRIVIA_QUESTIONS = GEOGRAPHY_TRIVIA_QUESTIONS;
				TRIVIA_ANSWERS1 = GEOGRAPHY_TRIVIA_ANSWERS1;
				TRIVIA_ANSWERS2 = GEOGRAPHY_TRIVIA_ANSWERS2;
				TRIVIA_ANSWERS3 = GEOGRAPHY_TRIVIA_ANSWERS3;
				TRIVIA_ANSWERS4 = GEOGRAPHY_TRIVIA_ANSWERS4;
				TRIVIA_ANSWERS5 = GEOGRAPHY_TRIVIA_ANSWERS5;
				TRIVIA_ANSWERS6 = GEOGRAPHY_TRIVIA_ANSWERS6;
				TRIVIA_ANSWERS7 = GEOGRAPHY_TRIVIA_ANSWERS7;
				TRIVIA_ANSWERS8 = GEOGRAPHY_TRIVIA_ANSWERS8;
			end
			
			-- Initialise the record
			TRIVIA_TIME_RECORD = {["time"] = TRIVIA_CONFIG.QUESTION_TIMEOUT + 1, ["holder"] = "noone"};
			
			-- Generate the question order.
			Trivia_RandomiseOrder();
			
			-- Set loaded state
			TRIVIA_LOADED = true;
		end
		
	elseif (event == "CHAT_MSG_CHANNEL") then
		local msg = arg1;
		local player = arg2;
        local channel = string.lower(arg9);

        if( (msg and msg ~= nil) and (player and player ~= nil) and (channel ~= nil) ) then
            if( string.lower(channel) == string.lower(TRIVIA_CONFIG.CHANNEL) and TRIVIA_ACCEPT_ANSWERS ) then
				Trivia_CheckAnswer(player, msg);
            end
		end
	
	elseif ((event == "CHAT_MSG_SAY" or event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_RAID_LEADER"
		 or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_PARTY") and TRIVIA_ACCEPT_ANSWERS) then
		
		-- Something was said, and the bot is on
		local msg = arg1;
		local player = arg2;

        if( (msg and msg ~= nil) and (player and player ~= nil)) then
			Trivia_CheckAnswer(player, msg);
		end
	
	elseif(event == "CHAT_MSG_SYSTEM" and (arg1 == ERR_TOO_MANY_CHAT_CHANNELS)) then
		Trivia_UnSchedule("all");
		Trivia_ConsoleMessage("Leave another channel before setting a new Private Channel");
		
	elseif (event == "RETRY_CHANNEL_CHANGE") then
		Trivia_ChangePrivateChannel();
		
	elseif (event == "NEXT_QUESTION") then
		TRIVIA_ACCEPT_ANSWERS = true;
		TriviaGUISkipButton:Enable();
		Trivia_AskQuestion();
		
	elseif (event == "QUESTION_TIMEOUT") then
		Trivia_QuestionTimeout();
		
	elseif (event == "QUESTION_WARN") then
		Trivia_SendMessage(TRIVIA_CONFIG.QUESTION_TIMEWARN .. " seconds left!");
		
	elseif (event == "REPORT_SCORERS") then
		Trivia_Report("gamereport");
	
	elseif (event == "END_REPORT") then
		Trivia_Report("endreport");
		
	elseif (event == "STOP_GAME") then
		Trivia_Stop();
		
	elseif (event == "START_ANNOUNCE") then
		if (TRIVIA_CONFIG.ROUND_SIZE == 0) then
			Trivia_SendMessage("TriviaBot started");
			Trivia_SendMessage("TriviaBot started [Unlimited question round]");
			Trivia_SendMessage("Submit Questions to Gurky @ https://github.com/Gurky-Kronos/TriviaBot/issues");			
		else
			Trivia_SendMessage("TriviaBot started [" .. TRIVIA_CONFIG.ROUND_SIZE .. " question round]");
			Trivia_SendMessage("Submit Questions to Gurky @ https://github.com/Gurky-Kronos/TriviaBot/issues");				
		end
		
	elseif (event == "SHOW_ANSWER") then
		Trivia_SendMessage("The correct answer was: " .. TRIVIA_ANSWERS1[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]]);
	end
	
end

function Trivia_Help()
	
	-- Prints instructions
	Trivia_ConsoleMessage("'/trivia channel [SAY|PARTY|RAID|GUILD|<custom channel>]' - Sets the trivia channel.");
    Trivia_ConsoleMessage("'/trivia start' - Starts the trivia game.");
    Trivia_ConsoleMessage("'/trivia stop' - Stops the current game.");
	Trivia_ConsoleMessage("'/trivia skip' - Skips the current question.");
	Trivia_ConsoleMessage("'/trivia shuffle' - Shuffles the questions (restarts from beginning).");
	Trivia_ConsoleMessage("'/trivia clear' - Clears the scores.");
	Trivia_ConsoleMessage("'/trivia answer [your answer]' - Enter your answer when in Console Play mode");
	Trivia_ConsoleMessage("'/trivia qlist [wow|normal|turtle|geography]' Select the question list.");
	Trivia_ConsoleMessage("'/trivia help' shows this information.");
	
end

function Trivia_Shuffle()
	if (TRIVIA_RUNNING) then
		Trivia_UnSchedule("all"); -- Stop the current question
		Trivia_SendMessage("Questions shuffled. Restarting with a new question in 5 seconds");
		TRIVIA_ACCEPT_ANSWERS = false;
		Trivia_RandomiseOrder();
		Trivia_Schedule("NEXT_QUESTION", 5); -- Schedule a new one
	else
		Trivia_RandomiseOrder();
		Trivia_ConsoleMessage("Questions shuffled.");
	end
end

function Trivia_QListSelect(input)
	if (not TRIVIA_ACCEPT_ANSWERS) then
		if (input == "normal") then
			Trivia_ConsoleMessage("Normal question set selected");
			TRIVIA_CONFIG.QLIST = "normal";
			TRIVIA_QUESTIONS = NORMAL_TRIVIA_QUESTIONS;
			TRIVIA_ANSWERS1 = NORMAL_TRIVIA_ANSWERS1;
			TRIVIA_ANSWERS2 = NORMAL_TRIVIA_ANSWERS2;
			TRIVIA_ANSWERS3 = NORMAL_TRIVIA_ANSWERS3;
			TRIVIA_ANSWERS4 = NORMAL_TRIVIA_ANSWERS4;
			TRIVIA_ANSWERS5 = NORMAL_TRIVIA_ANSWERS5;
			TRIVIA_ANSWERS6 = NORMAL_TRIVIA_ANSWERS6;
			TRIVIA_ANSWERS7 = NORMAL_TRIVIA_ANSWERS7;
			TRIVIA_ANSWERS8 = NORMAL_TRIVIA_ANSWERS8;
			Trivia_RandomiseOrder();
		elseif (input == "wow") then
			Trivia_ConsoleMessage("WoW question set selected");
			TRIVIA_CONFIG.QLIST = "wow";
			TRIVIA_QUESTIONS = WOW_TRIVIA_QUESTIONS;
			TRIVIA_ANSWERS1 = WOW_TRIVIA_ANSWERS1;
			TRIVIA_ANSWERS2 = WOW_TRIVIA_ANSWERS2;
			TRIVIA_ANSWERS3 = WOW_TRIVIA_ANSWERS3;
			TRIVIA_ANSWERS4 = WOW_TRIVIA_ANSWERS4;
			TRIVIA_ANSWERS5 = WOW_TRIVIA_ANSWERS5;
			TRIVIA_ANSWERS6 = WOW_TRIVIA_ANSWERS6;
			TRIVIA_ANSWERS7 = WOW_TRIVIA_ANSWERS7;
			TRIVIA_ANSWERS8 = WOW_TRIVIA_ANSWERS8;
			Trivia_RandomiseOrder();
		elseif (input == "turtle") then
			Trivia_ConsoleMessage("Turtle question set selected");
			TRIVIA_CONFIG.QLIST = "turtle";
			TRIVIA_QUESTIONS = TURTLE_TRIVIA_QUESTIONS;
			TRIVIA_ANSWERS1 = TURTLE_TRIVIA_ANSWERS1;
			TRIVIA_ANSWERS2 = TURTLE_TRIVIA_ANSWERS2;
			TRIVIA_ANSWERS3 = TURTLE_TRIVIA_ANSWERS3;
			TRIVIA_ANSWERS4 = TURTLE_TRIVIA_ANSWERS4;
			TRIVIA_ANSWERS5 = TURTLE_TRIVIA_ANSWERS5;
			TRIVIA_ANSWERS6 = TURTLE_TRIVIA_ANSWERS6;
			TRIVIA_ANSWERS7 = TURTLE_TRIVIA_ANSWERS7;
			TRIVIA_ANSWERS8 = TURTLE_TRIVIA_ANSWERS8;
			Trivia_RandomiseOrder();
		elseif (input == "geography") then
			Trivia_ConsoleMessage("Geography question set selected");
			TRIVIA_CONFIG.QLIST = "geography";
			TRIVIA_QUESTIONS = GEOGRAPHY_TRIVIA_QUESTIONS;
			TRIVIA_ANSWERS1 = GEOGRAPHY_TRIVIA_ANSWERS1;
			TRIVIA_ANSWERS2 = GEOGRAPHY_TRIVIA_ANSWERS2;
			TRIVIA_ANSWERS3 = GEOGRAPHY_TRIVIA_ANSWERS3;
			TRIVIA_ANSWERS4 = GEOGRAPHY_TRIVIA_ANSWERS4;
			TRIVIA_ANSWERS5 = GEOGRAPHY_TRIVIA_ANSWERS5;
			TRIVIA_ANSWERS6 = GEOGRAPHY_TRIVIA_ANSWERS6;
			TRIVIA_ANSWERS7 = GEOGRAPHY_TRIVIA_ANSWERS7;
			TRIVIA_ANSWERS8 = GEOGRAPHY_TRIVIA_ANSWERS8;
			Trivia_RandomiseOrder();
		else
			Trivia_ConsoleMessage("Unrecognised question set. Try '/trivia qlist'");
		end
	else
		Trivia_ConsoleMessage("Stop the trivia bot first!");
	end
end

function Trivia_RandomiseOrder()
	-- Randomise the order of the questions
	TRIVIA_QUESTION_ORDER = {};
	
	-- Initialise the table
	local noOfQuestions = table.getn(TRIVIA_QUESTIONS);
	local n = 1;
	
	while (n <= noOfQuestions) do
		TRIVIA_QUESTION_ORDER[n] = n;
		n = n + 1;
	end
	
	local tmp, random;
	local i;
	local j = 5;
	
	while (j > 0) do
		i = 1;
		-- Swap each element with a random element
		while (i <= noOfQuestions) do
			random = math.random(noOfQuestions);
			tmp = TRIVIA_QUESTION_ORDER[i];
			TRIVIA_QUESTION_ORDER[i] = TRIVIA_QUESTION_ORDER[random]
			TRIVIA_QUESTION_ORDER[random] = tmp;
			i = i + 1;
		end
		
		-- Decrement J
		j = j - 1
	end
	
end

-- Channel Select
function Trivia_ChannelSelect(type, name)
	
	-- Leave the old private channel (if there was one)
	if (TRIVIA_CONFIG.CHANNEL_TYPE == "private") then
		if (GetChannelName(TRIVIA_CONFIG.CHANNEL) > 0) then
			LeaveChannelByName(TRIVIA_CONFIG.CHANNEL);
		end
	end
	
	-- Check the new channel type
	if (type ~= "private") then
		-- Simply set the new type
		TRIVIA_CONFIG.CHANNEL_TYPE = type;
		Trivia_ConsoleMessage("Channel changed to: " .. string.upper(type));
	else
		-- We need to join change to the new private channel
		-- First Check for protected channels
		local newChannel = string.lower(name);
		if (newChannel == "general" or newChannel == "trade" or newChannel == "lookingforgroup" or newChannel == "guildrecruitment" or newChannel == "localdefense" or newChannel == "worlddefense") then
				-- Announce protected Channel
				Trivia_ErrorMessage("Channel '" .. TRIVIA_NEW_CHANNEL .. "' is protected, unable to change channel.");
				TRIVIA_CONFIG.CHANNEL_TYPE = "none";
		else
			TRIVIA_NEW_CHANNEL = name;
			Trivia_ChangePrivateChannel();
			TRIVIA_CONFIG.CHANNEL_TYPE = "private";
		end
	end
	
	-- Update the GUI
	Trivia_GUIUpdate();
	
end


-- Channel changer
function Trivia_ChangePrivateChannel()
	
	-- Check the old channel is really gone

	if (GetChannelName(TRIVIA_CONFIG.CHANNEL) > 0) then
		-- It still exists, try to leave it, and re-try this method.
		LeaveChannelByName(TRIVIA_CONFIG.CHANNEL);
		Trivia_Schedule("RETRY_CHANNEL_CHANGE", 1);
	else
		-- Set and join the channel
		JoinChannelByName(TRIVIA_NEW_CHANNEL);
		ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, TRIVIA_NEW_CHANNEL);
	
		-- Check the channel exists now
		if (GetChannelName(TRIVIA_NEW_CHANNEL) > 0) then
			-- Finalise the Change
			TRIVIA_CONFIG.CHANNEL = TRIVIA_NEW_CHANNEL;
		
			-- Announce the action
			Trivia_ConsoleMessage("Channel set to: "..TRIVIA_CONFIG.CHANNEL);
	
		else
			-- It doesn't exist yet, re-try
			Trivia_Schedule("RETRY_CHANNEL_CHANGE", 1);
		end
	end
	
	-- Update GUI
	Trivia_GUIUpdate();

end

function Trivia_EndQuestion(showAnswer)
	-- Called when a question is finished
	
	-- Prevent further answers
	TRIVIA_ACCEPT_ANSWERS = false;
	TriviaGUISkipButton:Disable();

	-- Increment the counters
	TRIVIA_ROUND_COUNTER = TRIVIA_ROUND_COUNTER  + 1;
	
	local wait = 0;
	if (showAnswer) then
		wait = wait + 4;
		Trivia_Schedule("SHOW_ANSWER", wait);
		
	end
	
	-- See if we've reached the end of the round
	if (TRIVIA_ROUND_COUNTER + 1 == TRIVIA_CONFIG.ROUND_SIZE + 1) then
		Trivia_Schedule("END_REPORT", wait + 4);
		Trivia_Schedule("STOP_GAME", wait + 8);
	else
		-- Count how long it's been since a question report
		if (TRIVIA_CONFIG.SHOW_REPORTS) then
			TRIVIA_REPORT_COUNTER = TRIVIA_REPORT_COUNTER + 1;
			if (TRIVIA_REPORT_COUNTER == TRIVIA_CONFIG.REPORT_INTERVAL) then
				wait = wait + 4;
				Trivia_Schedule("REPORT_SCORERS", wait);
				TRIVIA_REPORT_COUNTER = 0;
			end
		end
		
		Trivia_Schedule("NEXT_QUESTION", TRIVIA_CONFIG.INTERVAL + wait);
	end
	
end

-- Asks a question
function Trivia_AskQuestion()

	TRIVIA_ACTIVE_QUESTION = TRIVIA_ACTIVE_QUESTION + 1;

	-- Check there is questions left
	if (TRIVIA_ACTIVE_QUESTION == (table.getn(TRIVIA_QUESTIONS) + 1)) then
		-- Reshuffle the order
		Trivia_RandomiseOrder();
		TRIVIA_ACTIVE_QUESTION = 1;
		Trivia_ConsoleMessage("Out of questions... Reshuffled and restarted.\n|cffFFFF00Submit Questions to Gurky @ https://github.com/Gurky-Kronos/TriviaBot/issues|r");
		Trivia_SendMessage("Out of questions - Restarting");
		if (TRIVIA_CONFIG.QLIST == "wow") then
			Trivia_SendMessage("Submit Questions to Gurky @ https://github.com/Gurky-Kronos/TriviaBot/issues");
		end
	end
	
	local questionNumber = "";
	if (TRIVIA_CONFIG.ROUND_SIZE + 1 ~= 1) then
		questionNumber = TRIVIA_ROUND_COUNTER + 1;
	end
	
	for ce in string.gmatch(TRIVIA_QUESTIONS[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]],"Quote") do
	c = ce;
    end
    if c == 0 then
	Trivia_SendMessage("Q" .. questionNumber .. ": " .. TRIVIA_QUESTIONS[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]]);
	c = 0;
	else
    Trivia_SendMessage(TRIVIA_QUESTIONS[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]]);	
	end
	c = 0;
	TRIVIA_QUESTION_STARTTIME = GetTime();
	TRIVIA_ACCEPT_ANSWERS = true;
    Trivia_Schedule("QUESTION_TIMEOUT", TRIVIA_CONFIG.QUESTION_TIMEOUT);
	Trivia_Schedule("QUESTION_WARN", TRIVIA_CONFIG.QUESTION_TIMEOUT - TRIVIA_CONFIG.QUESTION_TIMEWARN);
end

-- Answers the question and prepares the next if no one successfully answered the question
function Trivia_QuestionTimeout()
    Trivia_SendMessage("Time is up! No correct answer was given.");
	
	Trivia_EndQuestion(TRIVIA_CONFIG.SHOW_ANSWERS);	
end

-- Skip a question
function Trivia_SkipQuestion()
	-- Skip a question
	if (TRIVIA_RUNNING) then
		Trivia_SendMessage("Question was skipped.");
		Trivia_UnSchedule("all");
		TRIVIA_ACCEPT_ANSWERS = false;
			
		-- Show the answer anyway (for those that wanted to know)
		if (TRIVIA_CONFIG.SHOW_ANSWERS) then
			Trivia_Schedule("SHOW_ANSWER", 2);
		end
			
		-- Schedule the next question
		Trivia_Schedule("NEXT_QUESTION", 6);
		
		Trivia_ConsoleMessage("Question skipped");
	else
		Trivia_ErrorMessage("No game running!");
	end
end

function Trivia_Start()
	if (TRIVIA_CONFIG.CHANNEL_TYPE == "none") then
		Trivia_ErrorMessage("No channel set, could not start");
	else
		-- Set Running
		TRIVIA_RUNNING = true;
		
		-- Announce the start
		if (TRIVIA_CONFIG.CHANNEL_TYPE == "private") then
			Trivia_ConsoleMessage("Trivia started in Private Channel: " .. TRIVIA_CONFIG.CHANNEL);
		else
			Trivia_ConsoleMessage("Trivia started in " .. TRIVIA_CONFIG.CHANNEL_TYPE .. " channel");
		end
				
		Trivia_ConsoleMessage("First question coming up!");
		
		-- Schedule start
		Trivia_Schedule("START_ANNOUNCE", 2);
		Trivia_Schedule("NEXT_QUESTION", 7);
		
		-- Clear scores
		TRIVIA_SCORES = {};
		TRIVIA_REPORT_COUNTER = 0;
		TRIVIA_TIME_RECORD = {["time"] = TRIVIA_CONFIG.QUESTION_TIMEOUT + 1, ["holder"] = "noone"};
		
		-- Reset Round and Report Counters
		TRIVIA_REPORT_COUNTER = 0;
		TRIVIA_ROUND_COUNTER = 0;
		
		-- GUI Functions:
		TriviaGUIStartStopButton:SetText("Stop Trivia");
		TriviaGUIStartStopButton:SetNormalTexture("Interface\\AddOns\\TriviaBot\\images\\stop.tga")
	end
end

function Trivia_Stop(supressMessage)
	-- Clear all scheduled events
    Trivia_UnSchedule("all");
    TRIVIA_ACCEPT_ANSWERS = false;
	TRIVIA_RUNNING = false;
	
	if (not supressMessage) then
		Trivia_SendMessage("TriviaBot stopped.");
	end
	
	Trivia_ConsoleMessage("TriviaBot stopped.")
	
	-- GUI Updates
	TriviaGUIStartStopButton:SetText("Start Trivia");
	TriviaGUIStartStopButton:SetNormalTexture("Interface\\AddOns\\TriviaBot\\images\\start.tga")
	TriviaGUISkipButton:Disable();
end

function Trivia_CheckAnswer(player, msg)
    if ((string.lower(msg) == string.lower(TRIVIA_ANSWERS1[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
        (TRIVIA_ANSWERS2[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS2[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
        (TRIVIA_ANSWERS3[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS3[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
	    (TRIVIA_ANSWERS4[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS4[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
		(TRIVIA_ANSWERS5[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS5[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
		(TRIVIA_ANSWERS6[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS6[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
		(TRIVIA_ANSWERS7[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS7[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]])) or
		(TRIVIA_ANSWERS8[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]] ~= nil and string.lower(msg) == string.lower(TRIVIA_ANSWERS8[TRIVIA_QUESTION_ORDER[TRIVIA_ACTIVE_QUESTION]]))
		) then
        -- Correct answer
		
		 Trivia_SendMessage("'".. msg .. "' is the correct answer, "..player..".");
		 
		-- Unschedule warnings and timeout
		Trivia_UnSchedule("all");
		
		-- Time the answer
		local timeTaken = GetTime() - TRIVIA_QUESTION_STARTTIME;
		
		-- Round it 
		timeTaken = math.floor(timeTaken  * 10^2 + 0.5) / 10^2;
		
		-- Announce if it was quick
		if (timeTaken < TRIVIA_TIME_RECORD["time"]) then
			Trivia_SendMessage("NEW RECORD! Answered in: " .. timeTaken .. " sec");
			TRIVIA_TIME_RECORD["holder"] = player;
			TRIVIA_TIME_RECORD["time"] = timeTaken;
		end
		
        local score = TRIVIA_SCORES[player];
        if (score) then
			score = score + 1;
        else
			score = 1;
        end

        TRIVIA_SCORES[player] = score;
		
		Trivia_EndQuestion(false);
		
    end
end

function Trivia_Report(type)
	
	if (type == "gamereport") then
		-- Sort the table
		local TRIVIA_SORTED = {};
		
		local exists;
		for player, score in pairs(TRIVIA_SCORES) do
			-- Add them to the sorting table
			exists = true;
			table.insert(TRIVIA_SORTED, {["player"] = player, ["score"] = score});
		end
		
		table.sort(TRIVIA_SORTED, function(v1, v2)
			return v1["score"] > v2["score"];
			end);
		
		if (exists) then
			Trivia_SendMessage("Standing so far:");
		else
			Trivia_SendMessage("Standing: No points earnt yet!");
		end
		
		-- Report the top 3 scorers
		for id, record in pairs(TRIVIA_SORTED) do
			if (id <= 3) then
				-- Report the top 3
				
				-- Ensure correct grammar.
				local ess = "s";
				if (record["score"] == 1) then
					ess = "";
				end
	
				Trivia_SendMessage(id .. "]: " .. record["player"] .. " (" .. record["score"] .." point" .. ess .. ")");
				
			end
		end
		
		-- Speed record holder
		if (TRIVIA_TIME_RECORD["holder"] ~= "noone") then
			Trivia_SendMessage("Speed Record: " .. TRIVIA_TIME_RECORD["holder"] .. " in " .. TRIVIA_TIME_RECORD["time"] .. " sec");
		end
	elseif(type == "endreport") then
		-- Show the winner
		-- Sort the table
		local TRIVIA_SORTED = {};
		
		local exists;
		for player, score in pairs(TRIVIA_SCORES) do
			-- Add them to the sorting table
			exists = true;
			table.insert(TRIVIA_SORTED, {["player"] = player, ["score"] = score});
		end
		
		if (exists) then
			Trivia_SendMessage("GAME OVER! Final standings:");
		else
			Trivia_SendMessage("GAME OVER! Nobody scored!");
		end
		
		table.sort(TRIVIA_SORTED, function(v1, v2)
			return v1["score"] > v2["score"];
			end);
	
		-- Report the top 3 scorers
		for id, record in pairs(TRIVIA_SORTED) do
			if (id <= 2) then
				-- Report the winner and runner up
				
				-- Ensure correct grammar.
				local ess = "s";
				if (record["score"] == 1) then
					ess = "";
				end
				
				-- Announce standing
				local standing;
				if (id == 1) then
					standing = "WINNER";
				elseif (id == 2) then
					standing = "RUNNER UP"
				end
	
				Trivia_SendMessage(standing .. ": " .. record["player"] .. " (" .. record["score"] .." point" .. ess .. ")");
				
			end
		end
		
		-- Speed record holder
		if (TRIVIA_TIME_RECORD["holder"] ~= "noone") then
			Trivia_SendMessage("QUICKEST FINGERS: " .. TRIVIA_TIME_RECORD["holder"] .. " in " .. TRIVIA_TIME_RECORD["time"] .. " sec");
		end
	end
end


function Trivia_ClearTells(player)
	TRIVIA_TELLS[player] = nil;
end


function Trivia_DoSchedule()
		-- TO DO: Make some stuff
	if (TRIVIA_SCHEDULE ~= nil)	then
		for id, events in pairs(TRIVIA_SCHEDULE) do
			-- Get the time of each event
			-- If it should be run (i.e. equal or less than current time)
			if (events["time"] <= GetTime()) then
				Trivia_OnEvent(events["name"]);
				Trivia_UnSchedule(id);
			end
		end
	end
end

function Trivia_Schedule(name, time)
		-- Schedule an event
		thisEvent = {["name"] = name, ["time"] = GetTime() + time};
		table.insert(TRIVIA_SCHEDULE, thisEvent);
end

function Trivia_UnSchedule(id)
		-- Unschedule an event
		
		if (id == "all") then
			TRIVIA_SCHEDULE = {};
		else
			table.remove(TRIVIA_SCHEDULE, id);
		end
end


function Trivia_SendMessage(msg)
	-- Send a message to the trivia channel
	
	-- Prepend the trivia tag to each message 
	local triviaMsg;
	triviaMsg= "[TriviaBot]: " .. msg;
	
	-- Send the message to the right channel.
	if (TRIVIA_CONFIG.CHANNEL_TYPE == "guild") then
		SendChatMessage(triviaMsg, "GUILD");
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "say") then
		SendChatMessage(triviaMsg, "SAY");
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "party") then
		SendChatMessage(triviaMsg, "PARTY");
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "raid") then
		SendChatMessage(triviaMsg, "RAID");
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "console") then
		Trivia_ConsoleMessage("Console Play: " .. msg);
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "private") then
		-- Check the channel exists, and send
		id = GetChannelName(TRIVIA_CONFIG.CHANNEL);
		
		if (id > 0) then
			SendChatMessage(triviaMsg, "CHANNEL", nil, id);
		else
			-- Channel send error, stop the current game
			Trivia_ErrorMessage("Unable to send to channel.");
			Trivia_ErrorMessage("Reset channel with '/trivia channel' or the 'Update Channel' button");
			Trivia_Stop(true);
		end
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "none") then
		-- No channel selected
		Trivia_ErrorMessage("No channel selected");
		Trivia_ErrorMessage("Reset channel with '/trivia channel'");
		Trivia_ErrorMessage("Current Trivia game stopped.");
		Trivia_UnSchedule("all");
		TRIVIA_ACCEPT_ANSWERS = false;
		TRIVIA_RUNNING = false;
	else
		Trivia_ErrorMessage("DEBUG CODE 01");
	end
	
end

function Trivia_ConsoleMessage(msg)
	-- Check the default frame exists
	if (DEFAULT_CHAT_FRAME) then
		-- Format the message
		msg = "|cffff8000Trivia: |r" .. WHITE .. msg;
		DEFAULT_CHAT_FRAME:AddMessage(msg);
	end
end

function Trivia_ErrorMessage(msg)
	-- Check the default frame exists
	if (DEFAULT_CHAT_FRAME) then
		-- Format the message
		msg = MAGENTA .. "Trivia: " .. RED .. "ERROR! - " .. WHITE .. msg;
		DEFAULT_CHAT_FRAME:AddMessage(msg);
	end
end


-- GUI FUNCTIONS

function Trivia_GUIUpdate()
	-- Update all the GUI elements as per the configuration
	
	--Channel Type
	if (TRIVIA_CONFIG.CHANNEL_TYPE == "say") then
		UIDropDownMenu_SetText("Say", TriviaGUIChatSelect);
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "console") then
		UIDropDownMenu_SetText("Console", TriviaGUIChatSelect);
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "party") then
		UIDropDownMenu_SetText("Party", TriviaGUIChatSelect);
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "guild") then
		UIDropDownMenu_SetText("Guild", TriviaGUIChatSelect);
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "raid") then
		UIDropDownMenu_SetText("Raid", TriviaGUIChatSelect);
	elseif (TRIVIA_CONFIG.CHANNEL_TYPE == "private") then
		UIDropDownMenu_SetText("Private Channel", TriviaGUIChatSelect);
	else
		-- Nothing selected
		UIDropDownMenu_SetText("None Selected", TriviaGUIChatSelect);
	end

	-- Question List
	if (TRIVIA_CONFIG.QLIST == "normal") then
		UIDropDownMenu_SetText("Normal", TriviaGUIQListSelect);
	elseif (TRIVIA_CONFIG.QLIST == "wow") then
		UIDropDownMenu_SetText("WoW", TriviaGUIQListSelect);
	elseif (TRIVIA_CONFIG.QLIST == "turtle") then
		UIDropDownMenu_SetText("Turtle", TriviaGUIQListSelect);
	elseif (TRIVIA_CONFIG.QLIST == "geography") then
		UIDropDownMenu_SetText("Geography", TriviaGUIQListSelect);
	else
		-- Nothing selected
		UIDropDownMenu_SetText("None Selected", TriviaGUIQListSelect);
	end
	
	-- Private Channel Entry
	if (TRIVIA_CONFIG.CHANNEL_TYPE == "private") then
		TriviaGUIChannelBox:EnableKeyboard(true);
		TriviaGUIChannelBox:EnableMouse(true);
		if (TRIVIA_NEW_CHANNEL ~= "none" and TRIVIA_NEW_CHANNEL ~= TRIVIA_CONFIG.CHANNEL) then
			TriviaGUIChannelBox:SetText("Changing...");
		else
			TriviaGUIChannelBox:SetText(TRIVIA_CONFIG.CHANNEL);
		end
		TriviaGUIChannelBox:SetTextColor(1, 1, 1);
		TriviaGUIChannelBox:SetJustifyH("LEFT");
		TriviaGUIChannelButton:Enable();
	else
		TriviaGUIChannelBox:EnableKeyboard(false);
		TriviaGUIChannelBox:EnableMouse(false);
		TriviaGUIChannelBox:SetText("DISABLED");
		TriviaGUIChannelBox:ClearFocus();
		TriviaGUIChannelBox:SetJustifyH("CENTER");
		TriviaGUIChannelBox:SetTextColor(1, 0, 0);
		TriviaGUIChannelButton:Disable();
	end
	
	-- Main Window
	if (TRIVIA_CONFIG.GUIENABLED) then
			TriviaGUI:Show();
	else
			TriviaGUI:Hide();
	end
	
	-- Version Code
	TriviaHeaderLabel:SetText("TriviaBot |cff1fff1f[Turtle WoW]|r");
	TriviaHeaderLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	TriviaHeaderLabel:SetTextColor(1.0, 0.55, 0.0);
	version:SetText("Version: " .. TRIVIA_VERSION);
	version:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE, ");
	version:SetTextColor(1.0, 0.55, 0.0);
	QuestionListLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	QuestionListLabel:SetTextColor(1.0, 0.55, 0.0);
	ChatSelectLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	ChatSelectLabel:SetTextColor(1.0, 0.55, 0.0);
	ChannelEditBoxLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	ChannelEditBoxLabel:SetTextColor(1.0, 0.55, 0.0);
	ShowAnswerLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	ShowAnswerLabel:SetTextColor(1.0, 0.55, 0.0);
	ReportScoresLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	ReportScoresLabel:SetTextColor(1.0, 0.55, 0.0);
	IntervalSelectLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	IntervalSelectLabel:SetTextColor(1.0, 0.55, 0.0);
	RoundSizeSelectLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	RoundSizeSelectLabel:SetTextColor(1.0, 0.55, 0.0);
	TimeoutSelectLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	TimeoutSelectLabel:SetTextColor(1.0, 0.55, 0.0);
	ShowLabel:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	ShowLabel:SetTextColor(1.0, 0.55, 0.0);
	TriviaGUIStartStopButton:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	TriviaGUIStartStopButton:SetTextColor(1.0, 0.55, 0.0);
	TriviaGUISkipButton:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	TriviaGUISkipButton:SetTextColor(1.0, 0.55, 0.0);
	TriviaGUIChannelButton:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, ");
	TriviaGUIChannelButton:SetTextColor(1.0, 0.55, 0.0);

	-- The check buttons
	TriviaGUIShowAnswerCheckBox:SetChecked(TRIVIA_CONFIG.SHOW_ANSWERS);
	TriviaGUIReportCheckBox:SetChecked(TRIVIA_CONFIG.SHOW_REPORTS);
	
	-- Interval
	if (TRIVIA_CONFIG.INTERVAL == 5) then
		UIDropDownMenu_SetText("5 seconds", TriviaGUIIntervalSelect);
	elseif (TRIVIA_CONFIG.INTERVAL == 10) then
		UIDropDownMenu_SetText("10 seconds", TriviaGUIIntervalSelect);
	elseif (TRIVIA_CONFIG.INTERVAL == 20) then
		UIDropDownMenu_SetText("20 seconds", TriviaGUIIntervalSelect);
	elseif (TRIVIA_CONFIG.INTERVAL == 30) then
		UIDropDownMenu_SetText("30 seconds", TriviaGUIIntervalSelect);
	elseif (TRIVIA_CONFIG.INTERVAL == 60) then
		UIDropDownMenu_SetText("1 minute", TriviaGUIIntervalSelect);
	elseif (TRIVIA_CONFIG.INTERVAL == 300) then
		UIDropDownMenu_SetText("5 minutes", TriviaGUIIntervalSelect);
	elseif (TRIVIA_CONFIG.INTERVAL == 600) then
		UIDropDownMenu_SetText("10 minutes", TriviaGUIIntervalSelect);
	else
		-- Nothing selected
		UIDropDownMenu_SetText("Not Set", TriviaGUIIntervalSelect);
	end

	-- Timeout
	UIDropDownMenu_SetText(TRIVIA_CONFIG.QUESTION_TIMEOUT .. "/" .. TRIVIA_CONFIG.QUESTION_TIMEWARN, TriviaGUITimeoutSelect);
	
	-- Round Size
	if (TRIVIA_CONFIG.ROUND_SIZE == 0) then
		UIDropDownMenu_SetText("Unlimited", TriviaGUIRoundSizeSelect);
	else
		UIDropDownMenu_SetText(TRIVIA_CONFIG.ROUND_SIZE, TriviaGUIRoundSizeSelect);
	end
	
end
		
		
		
-- ChatList
function TriviaGUIChatSelect_Initialize()

	-- The list of options
	local TRIVIA_CHATDROPDOWNLIST = {"Console", "Say", "Party", "Guild", "Raid", "Private Channel"};
	
	local info;
	-- Add them to the GUI Panel
	for i = 1, getn(TRIVIA_CHATDROPDOWNLIST), 1 do
		info = {};
		info.text = TRIVIA_CHATDROPDOWNLIST[i];
		info.func = TriviaGUIChatSelect_OnClick;
		UIDropDownMenu_AddButton(info);
	end

end

function TriviaGUIChatSelect_OnClick()

	-- Update the new selected ID
	UIDropDownMenu_SetSelectedID(TriviaGUIChatSelect, this:GetID());
	
	-- Set the channel type
	local type;
	if (this:GetText() == "Private Channel") then
		type = "private";
		Trivia_ChannelSelect(type, TRIVIA_CONFIG.CHANNEL);
	else
		type = string.lower(this:GetText());
		Trivia_ChannelSelect(type);
	end
	
	-- Warn for SAY
	if (this:GetText() == "Say") then
		Trivia_ConsoleMessage(RED .. "WARNING: " .. WHITE .. "Say Selected");
		Trivia_ConsoleMessage("Outputting questions to 'say' can be very annoying in busy areas");
		Trivia_ConsoleMessage("If people report you, your account may be suspended for spamming");
		Trivia_ConsoleMessage("Only use 'say' in quiet and/or instanced areas");
	end
	
end

-- QuestionList
function TriviaGUIQListSelect_Initialize()

	-- The list of options
	local TRIVIA_QLISTDROPDOWNLIST = {"Normal", "WoW", "Turtle", "Geography"};
	
	local info;
	-- Add them to the GUI Panel
	for i = 1, getn(TRIVIA_QLISTDROPDOWNLIST), 1 do
		info = {};
		info.text = TRIVIA_QLISTDROPDOWNLIST[i];
		info.func = TriviaGUIQListSelect_OnClick;
		UIDropDownMenu_AddButton(info);
	end

end

function TriviaGUIQListSelect_OnClick()

	-- Update the new selected ID
	UIDropDownMenu_SetSelectedID(TriviaGUIQListSelect, this:GetID());
	
	-- Set the QList Type
	if (this:GetText() == "Normal") then
		Trivia_QListSelect("normal");
	elseif (this:GetText() == "WoW") then
		Trivia_QListSelect("wow");
	elseif (this:GetText() == "Turtle") then
		Trivia_QListSelect("turtle");
	elseif (this:GetText() == "Geography") then
		Trivia_QListSelect("geography");
	end
end
-- Round Size
function TriviaGUIRoundSizeSelect_Initialize()

	-- The list of options
	local TRIVIA_DROPDOWNLIST = {"Unlimited", 10, 20, 25, 50, 100};
	
	local info;
	-- Add them to the GUI Panel
	for i = 1, getn(TRIVIA_DROPDOWNLIST), 1 do
		info = {};
		info.text = TRIVIA_DROPDOWNLIST[i];
		info.func = TriviaGUIRoundSizeSelect_OnClick;
		UIDropDownMenu_AddButton(info);
	end

end

function TriviaGUIRoundSizeSelect_OnClick()


	
	-- Set the Round Size
	if (not TRIVIA_RUNNING) then
	
		-- Update the new selected ID
		UIDropDownMenu_SetSelectedID(TriviaGUIRoundSizeSelect, this:GetID());
	
		if (this:GetText() == "Unlimited") then
			TRIVIA_CONFIG.ROUND_SIZE = 0;
		else
			TRIVIA_CONFIG.ROUND_SIZE = this:GetText();
		end
	else
		Trivia_ErrorMessage("Game is running, could not update round size at this point");
	end
	
end


-- Question Interval
function TriviaGUIIntervalSelect_Initialize()

	-- The list of options
	local TRIVIA_DROPDOWNLIST = {"5 seconds", "10 seconds", "20 seconds", "30 seconds", "1 minute", "5 minutes", "10 minutes"};
	
	local info;
	-- Add them to the GUI Panel
	for i = 1, getn(TRIVIA_DROPDOWNLIST), 1 do
		info = {};
		info.text = TRIVIA_DROPDOWNLIST[i];
		info.func = TriviaGUIIntervalSelect_OnClick;
		UIDropDownMenu_AddButton(info);
	end

end

function TriviaGUIIntervalSelect_OnClick()

	-- Update the new selected ID
	UIDropDownMenu_SetSelectedID(TriviaGUIIntervalSelect, this:GetID());
	
	-- Set the new interval
	if (this:GetText() == "5 seconds") then
		TRIVIA_CONFIG.INTERVAL = 5;
	elseif (this:GetText() == "10 seconds") then
		TRIVIA_CONFIG.INTERVAL = 10;
	elseif (this:GetText() == "20 seconds") then
		TRIVIA_CONFIG.INTERVAL = 20;
	elseif (this:GetText() == "30 seconds") then
		TRIVIA_CONFIG.INTERVAL = 30;
	elseif (this:GetText() == "1 minute") then
		TRIVIA_CONFIG.INTERVAL = 60;
	elseif (this:GetText() == "5 minutes") then
		TRIVIA_CONFIG.INTERVAL = 300;
	elseif (this:GetText() == "10 minutes") then
		TRIVIA_CONFIG.INTERVAL = 600;
	end
end

-- Duration
function TriviaGUITimeoutSelect_Initialize()

	-- The list of options
	local TRIVIA_DROPDOWNLIST = {"120/45", "90/30", "60/30", "45/20", "30/15", "20/10"};
	
	local info;
	-- Add them to the GUI Panel
	for i = 1, getn(TRIVIA_DROPDOWNLIST), 1 do
		info = {};
		info.text = TRIVIA_DROPDOWNLIST[i];
		info.func = TriviaGUITimeoutSelect_OnClick;
		UIDropDownMenu_AddButton(info);
	end

end

function TriviaGUITimeoutSelect_OnClick()

	-- Update the new selected ID
	UIDropDownMenu_SetSelectedID(TriviaGUITimeoutSelect, this:GetID());
	
	-- Set the new Timeouts
	if (this:GetText() == "120/45") then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 120;
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 45;
	elseif (this:GetText() == "90/30") then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 90;
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 30;
	elseif (this:GetText() == "60/30") then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 60;
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 30;
	elseif (this:GetText() == "45/20") then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 45;
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 20;
	elseif (this:GetText() == "30/15") then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 30;
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 15;
	elseif (this:GetText() == "20/10") then
		TRIVIA_CONFIG.QUESTION_TIMEOUT = 20;
		TRIVIA_CONFIG.QUESTION_TIMEWARN = 10;
	end
end

function TriviaGUI_ChannelButton_OnClick()

	-- Set the new private channel
	Trivia_ChannelSelect("private", TriviaGUIChannelBox:GetText());
	TriviaGUIChannelBox:ClearFocus();
	
end

function TriviaGUI_StartStopButton_OnClick()

	-- Check if there is a game running
	if (TRIVIA_RUNNING) then
		-- Stop the game
		Trivia_Stop();
	else
		-- Start a new game
		Trivia_Start();
	end
end

function TriviaGUIReportCheckBox_OnClick()
	TRIVIA_CONFIG.SHOW_REPORTS = this:GetChecked();
end

function TriviaGUIShowAnswerCheckBox_OnClick()
	TRIVIA_CONFIG.SHOW_ANSWERS = this:GetChecked();
end


function TriviaGUI_OnDragStart()		
	TriviaGUI:StartMoving();
	Trivia_ConsoleMessage("DRAG");
end


function TriviaGUI_OnDragStop()
	TriviaGUI:StopMovingOrSizing();
	Trivia_ConsoleMessage("DRAGSOTP");
end





