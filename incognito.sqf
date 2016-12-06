diag_log "INCOGNITO loaded";

RYD_INC_Diff = 0.5;

RYD_INC_Switch =
	{
	switch (RYD_INC_Diff) do
		{
		case (0.5) : {RYD_INC_Diff = 1;hint format ["Incognito set to NORMAL\nsafe distance: 100%1\nnotifications: LIMITED",'%']};
		case (1) : {RYD_INC_Diff = 1.5;hint format ["Incognito set to HARD\nsafe distance: 150%1\nnotifications: NONE",'%']};
		case (1.5) : {RYD_INC_Diff = 0.5;hint format ["Incognito set to EASY\nsafe distance: 50%1\nnotifications: FULL",'%']};
		};
	};

_LOSCheck =
	{
	private ["_pos1","_pos2","_isLOS","_cam","_target","_pX1","_pY1","_pX2","_pY2","_pos1ATL","_pos2ATL","_lvl1","_lvl2","_pos1O","_pos2O"];

	_pos1O = _this select 0;
	_pos2O = _this select 1;

	_pos1 = getPosASL _pos1O;
	_pos2 = getPosASL _pos2O;

	_pX1 = _pos1 select 0;
	_pY1 = _pos1 select 1;

	_pX2 = _pos2 select 0;
	_pY2 = _pos2 select 1;

	_lvl1 = abs (((eyePos _pos1O) select 2) - (_pos1 select 2));
	_lvl2 = abs (((eyePos _pos2O) select 2) - (_pos2 select 2));

	_pos1ATL = [_pX1,_pY1,_lvl1];
	_pos2ATL = [_pX2,_pY2,_lvl2];

	_cam = objNull;

	if ((count _this) > 2) then {_cam = _this select 2};

	_target = objNull;

	if ((count _this) > 3) then {_target = _this select 3};

	_isLOS = not (terrainintersect [_pos1ATL, _pos2ATL]);

	if (_isLOS) then
		{
		_isLOS = not (lineintersects [_pos1, _pos2,_cam,_target]);
		};

	_isLOS
	};

_isFlanking =
	{
	private ["_point","_Rpoint","_angle","_diffA","_axis","_isFlanking","_eyeD"];

	_point = _this select 0;
	_rPoint = _this select 1;

	_eyeD = eyeDirection _rPoint;

	_axis = (_eyeD select 0) atan2 (_eyeD select 1);

	_angle = [getPosATL _rPoint,getPosATL _point,10] call _angTowards;

	_isFlanking = false;

	if (_angle < 0) then {_angle = _angle + 360};
	if (_axis < 0) then {_axis = _axis + 360};

	_diffA = _angle - _axis;

	if (_diffA < 0) then {_diffA = _diffA + 360};

	if ((_diffA > 45) and (_diffA < 315)) then
		{
		_isFlanking = true
		};

	_isFlanking
	};

_angTowards =
	{
	private ["_source0", "_target0", "_rnd0","_dX0","_dY0","_angleAzimuth0"];

	_source0 = _this select 0;
	_target0 = _this select 1;
	_rnd0 = _this select 2;

	_dX0 = (_target0 select 0) - (_source0 select 0);
	_dY0 = (_target0 select 1) - (_source0 select 1);

	_angleAzimuth0 = (_dX0 atan2 _dY0) + (random (2 * _rnd0)) - _rnd0;

	_angleAzimuth0
	};

_wasIncognito = false;
RYD_INC_Fired = -10;
_lastTxt = "Incognito status at risk";
_lastIncognito = 0;
_txt = "";

waituntil
	{
	sleep 1;

	not (isNull player)
	};

//_mainCycle = 0;

while {true} do
	{
	waituntil
		{
		sleep (2 + (random 2));

		not (isNull player)
		};

	//_mainCycle = _mainCycle + 1;

		{
		_switch = _x getvariable "RYD_INC_Switched";
		if isNil ("_switch") then
			{
			_x setVariable ["RYD_INC_Switched",true];
			_sw = [_x,"INCSwitch","","",""] call BIS_fnc_addCommMenuItem;
			}
		}
	foreach switchableUnits;

//_stoper = diag_Ticktime;

	_pgp = group player;
	_units = units _pgp;

		{
		_vh = vehicle _x;
		if not (_x == _vh) then
			{
			_fEHadded = _vh getVariable "RYD_INC_FEH";
			if (isNil "_fEHadded") then
				{
				_ix = _vh addEventHandler ["Fired",{if (({(_x in (_this select 0))} count (units (group player))) > 0) then {RYD_INC_Fired = time} else {(vehicle (_this select 0)) removeEventHandler ((vehicle (_this select 0)) getVariable "RYD_INC_FEH")}}];
				_vh setVariable ["RYD_INC_FEH",_ix];
				}
			}
		else
			{
			_fEHadded = _vh getVariable "RYD_INC_FEH";
			if (isNil "_fEHadded") then
				{
				_ix = _vh addEventHandler ["Fired",{RYD_INC_Fired = time}];
				_vh setVariable ["RYD_INC_FEH",_ix];
				}
			}
		}
	foreach _units;

	_sideP = configFile >> "CfgVehicles" >> (typeOf player) >> "Side";

	if (isNumber _sideP) then
		{
		_sideP = getNumber _sideP
		}
	else
		{
		_sideP = -1
		};

	switch (_sideP) do
		{
		case (0) : {_sideP = east};
		case (1) : {_sideP = west};
		case (2) : {_sideP = resistance};
		case (3) : {_sideP = civilian};
		default {_sideP = sideFriendly}
		};

	_knownForAll = 0;

	_vehs = [];
	_allEnemyG = [];

		{
		_knowAboutMe = [];
		_knowAboutMeG = [];
		_vh = vehicle _x;
		_asVh = assignedVehicle _x;

		if (isNull _asVh) then
			{
			_asVh = _vh
			};

			{
			if (((side _x) getFriend _sideP) < 0.6) then
				{
				if (((leader _x) distance _vh) < viewDistance) then
					{
					if (((_x knowsAbout _vh) max (_x knowsAbout _asVh)) > 1) then
						{
						_knowAboutMeG pushBack _x;

							{
							if not (captive _x) then
								{
								_knowAboutMe pushBack _x
								}
							}
						foreach (units _x);
						}
					};

				_allEnemyG pushBack _x
				}
			}
		foreach allGroups;

		_vehs pushBack [_x,_vh,_asVh,_knowAboutMe,_knowAboutMeG];
		}
	foreach _units;

		{
		_unit = _x select 0;
		_vh = _x select 1;
		_asVh = _x select 2;
		_enemies = _x select 3;
		_enemiesG = _x select 4;

		_onFoot = (_unit == _vh);

		_armed = false;
		_wrongVeh = false;
		_firing = false;
		_recognized = false;

		if ((_onFoot) and {(({not ((toLower _x) in ["","throw"])} count [(currentWeapon _unit),(primaryWeapon _unit),(secondaryWeapon _unit)]) > 0)}) then
			{
			_armed = true
			};

		if not (_armed) then
			{
			if not (_onFoot) then
				{
				_side = configFile >> "CfgVehicles" >> (typeOf _vh) >> "Side";

				if (isNumber _side) then
					{
					_side = getNumber _side
					}
				else
					{
					_side = -1
					};

				switch (_side) do
					{
					case (0) : {_side = east};
					case (1) : {_side = west};
					case (2) : {_side = resistance};
					case (3) : {_side = civilian};
					default {_side = sideFriendly}
					};

					{
					if (((side _x) getFriend _side) < 0.6) exitWith
						{
						_wrongVeh = true
						}
					}
				foreach _allEnemyG
				};

			if not (_wrongVeh) then
				{
				if ((time - RYD_INC_Fired) < 10) then
					{
					_firing = true
					};

				if not (_firing) then
					{
					_div = 3 + sunOrMoon;
					_safeDst = 80 * RYD_INC_Diff;

					if (_onFoot) then
						{
						_speed = [0,0,0] distance (velocity _vh);
						_stance = stance _unit;

						switch (_stance) do
							{
							case ("CROUCH") :
								{
								_div = _div/1.5;
								_safeDst = _safeDst * (1.25/(1.5 - (sunOrMoon/2)));
								};

							case ("PRONE") :
								{
								_div = _div/2;
								_safeDst = _safeDst * (1.5/(2 - sunOrMoon));
								};
							};

						if (_speed > 2.5) then
							{
							_safeDst = _safeDst * ((_speed - 1.5)^0.45);
							}
						}

					else
						{
						_safeDst = 50 * RYD_INC_Diff
						};

					_safeDst = _safeDst - ((_safeDst * (1 - sunOrMoon))/2);

						{
						if ((_x distance _vh) < _safeDst) then
							{
							if ((_x distance _vh) < (random (_safeDst/_div)) + (random (_safeDst/_div)) + (random (_safeDst/_div)) + (random (_safeDst/_div))) then
								{
								_flank = [_vh,_x] call _isFlanking;

								if not (_flank) then
									{
									_isLOS = [_x,_vh] call _LOSCheck;

									if (_isLOS) then {_recognized = true}
									}
								}
							};

						if (_recognized) exitWith {}
						}
					foreach _enemies
					}
				}
			};

		RYD_INC_Fired = -10;

		_unit setVariable ["RYD_INC_Compromised",((_unit getVariable ["RYD_INC_Exposed",false]) or {(_armed) or {(_wrongVeh) or {(_firing) or {(_recognized)}}}})];

		_knownFor = count _enemiesG;

		_unit setVariable ["RYD_INC_Exposed",false];

		if (_unit getVariable ["RYD_INC_Compromised",false]) then
			{
			if (_knownFor > 0) then
				{
				_unit setVariable ["RYD_INC_Exposed",true]
				}
			};

		if (_knownFor > 0) then
			{
			_knownForAll = _knownFor
			};

		if not (_unit getVariable ["RYD_INC_Exposed",false]) then
			{
			_unit setVariable ["RYD_INC_Undercover",true];
			_wasIncognito = true
			}
		else
			{
			_unit setVariable ["RYD_INC_Undercover",false]
			};

		/*if ((_unit getVariable ["RYD_INC_Exposed",false]) or {(_armed) or {(_wrongVeh) or {(_firing) or {(_recognized)}}}}) then
			{
			diag_log format ["unit %7 : %1 reason - exposed: %2 armed: %3 wrongVeh: %4 firing: %5 recognized: %6 weaponry: %8 vh: %9 unit: %10",time,(_unit getVariable ["RYD_INC_Exposed",false]),_armed,_wrongVeh,_firing,_recognized,name _unit,[(currentWeapon _unit),(primaryWeapon _unit),(secondaryWeapon _unit)],_vh,_unit];
			};*/
		}
	foreach _vehs;

	_exposed = {(_x getVariable ["RYD_INC_Exposed",false])} count _units;
	_compromised = {((_x getVariable ["RYD_INC_Compromised",false]) and {(_x getVariable ["RYD_INC_Undercover",false])})} count _units;
	_incognito = {(_x getVariable ["RYD_INC_Undercover",false]) and {not (_x getVariable ["RYD_INC_Compromised",false])}} count _units;

	/*if ((_compromised > 0) and {_lastIncognito > 0}) then
		{
		diag_log "at risk"
		};*/

	if (_exposed == 0) then
		{
			{
			_unit = _x;
			_unit setVariable ["RYD_INC_Settings",[behaviour _unit,combatMode _unit]];
			_unit setCombatMode "CARELESS";
			_unit setBehaviour "BLUE";
			_unit setCaptive true;
			}
		foreach _units
		}
	else
		{
			{
			_unit = _x;

			_unit setVariable ["RYD_INC_Undercover",false];
			_settings = _unit getVariable ["RYD_INC_Settings",["AWARE","YELLOW"]];
			_unit setCombatMode (_settings select 0);
			_unit setBehaviour (_settings select 1);
			_unit setCaptive false
			}
		foreach _units
		};

	//hintSilent format ["comp: %1 exp: %2 inc: %3",_compromised,_exposed,_incognito];

	if (RYD_INC_Diff < 1.5) then
		{
		if (_wasIncognito) then
			{
			_txt = "";
			switch (true) do
				{
				case (_exposed > 0) :
					{
					_txt = "You've been exposed!"
					};

				case (_incognito > _lastIncognito) :
					{
					if ((count _units) == 1) then
						{
						_txt = "You're now incognito"
						}
					else
						{
						if (_incognito == 1) then
							{
							_txt = "One of you is now incognito"
							}
						else
							{
							_txt = format ["The %1 of you are now incognito",_incognito]
							}
						}
					};

				default
					{
					if ((count _units) > 1) then
						{
						if (_compromised > 0) then
							{
							if (_lastIncognito > 0) then
								{
								_txt = format ["Incognito status at risk for %1 of you",_compromised]
								}
							};

						if (RYD_INC_Diff < 1) then
							{
							if (_knownForAll > 0) then
								{
								if (_knownForAll == 1) then
									{
									_txt = _txt + (format ["\nOne of you is being observed",_knownForAll])
									}
								else
									{
									_txt = _txt + (format ["\nThe %1 of you are being observed",_knownForAll])
									}
								}
							}
						}
					else
						{
						switch (true) do
							{
							case (_compromised > 0) :
								{
								if (_lastIncognito > 0) then
									{
									_txt = "Incognito status at risk"
									}
								};

							case (_knownForAll > 0) :
								{
								if (RYD_INC_Diff < 1) then
									{
									_txt = "You're being observed"
									}
								}
							}
						}
					}
				}
			};

		//if (_mainCycle > 10) then
			//{
			if not (_txt in [""]) then
				{
				if not (_lastTxt in [_txt]) then
					{
					//titleText [_txt,"PLAIN DOWN",0.55];
					hintSilent _txt;
					_lastTxt = _txt
					}
				}
			//}
		};

	_lastIncognito = _incognito;

	//player sidechat format ["czas: %1",diag_Ticktime - _stoper]
	};
