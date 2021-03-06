RYD_INC_Diff = 0.5; // EASY

LOSCheck = {
	params ["_obj1", "_obj2"];

	diag_log "LOSCHECK";
	diag_log [_obj1, _obj2];

	private _pos1 = getPosASL _obj1;
	private _pos2 = getPosASL _obj2;

	!(terrainintersectASL [_pos1, _pos2]) && {!(lineintersects [_pos1, _pos2])};
};

isFlanking = {
	params ["_point", "_rPoint"];
	private ["_angle","_diffA","_axis","_eyeD"];

	_eyeD = eyeDirection _rPoint; // 3D Vector
	_axis = (_eyeD select 0) atan2 (_eyeD select 1); // arctangent, so angle of eyes

	_angle = [getPosATL _rPoint,getPosATL _point,10] call angTowards;

	if (_angle < 0) then {_angle = _angle + 360};
	if (_axis < 0) then {_axis = _axis + 360};

	_diffA = _angle - _axis;

	if (_diffA < 0) then {_diffA = _diffA + 360};

	(_diffA > 45) && (_diffA < 315);
};

angTowards = {
	params ["_source0", "_target0", "_rnd0"];
	private ["_dX0","_dY0","_angleAzimuth0"];

	_dX0 = (_target0 select 0) - (_source0 select 0);
	_dY0 = (_target0 select 1) - (_source0 select 1);

	_angleAzimuth0 = (_dX0 atan2 _dY0) + (random (2 * _rnd0)) - _rnd0;

	_angleAzimuth0;
};

getTrueVehicleSide = {
	params ["_vh"];
	_side = configFile >> "CfgVehicles" >> (typeOf _vh) >> "Side";

	_side = if (isNumber _side) then { getNumber _side } else { -1 };

	switch (_side) do {
		case (0) : { east };
		case (1) : { west };
		case (2) : { resistance };
		case (3) : { civilian };
		case (4) : { sideEmpty };
		case (5) : { sideEnemy };
		default { sideFriendly };
	};
};

RYD_INC_Fired = -10;
lastIncognito = 0;
lastTxt = "Incognito status at risk";

waituntil {
	sleep 1;
	!(isNull player);
};

[{
	// Add player comm menu item for adjusting difficulty
	_switch = player getvariable "RYD_INC_Switched";
	if isNil ("_switch") then {
		player setVariable ["RYD_INC_Switched",true];
		[player,"INCSwitch","","",""] call BIS_fnc_addCommMenuItem;
	};

	_pgp = group player;
	_units = units _pgp;

	{ // attach event handlers to all units/vehicles in player group
		_vh = vehicle _x; // get vehicle of the unit
		if !(_x == _vh) then { // if we're in a vehicle
			_fEHadded = _vh getVariable "RYD_INC_FEH"; // look for the event handler
			if (isNil "_fEHadded") then { // if not there, attach it
				_ix = _vh addEventHandler ["Fired",
				  {
						if (({ (_x in (_this select 0)) } count _units) > 0) then { // if this vehicle is in player's group
							RYD_INC_Fired = time // last time we fired was ...
						} else { // vehicle no longer in player group, remove event handler
							private _i = vehicle (_this select 0);
							private _eh = _i getVariable "RYD_INC_FEH";
							_i removeEventHandler _eh;
						};
					}
				];
				_vh setVariable ["RYD_INC_FEH", _ix];
			};
		} else { // we are not in a vehicle
			_fEHadded = _vh getVariable "RYD_INC_FEH";
			if (isNil "_fEHadded") then { // attach event handler to player
				_ix = _vh addEventHandler ["Fired",{ RYD_INC_Fired = time} ];
				_vh setVariable ["RYD_INC_FEH",_ix];
			};
		};
	} foreach _units;

	_sideP = [player] call getTrueVehicleSide; // this gets the side of the player uniform (I think?)
	_knownForAll = 0;
	_vehs = [];
	_allEnemyG = [];

	{ // for each unit, find out who knows about it
		_knowAboutMe = [];
		_knowAboutMeG = [];
		_vh = vehicle _x;
		_asVh = assignedVehicle _x;

		if (isNull _asVh) then { _asVh = _vh };

		{ // iterate through all groups to get enemies who are within viewdistance
			if (((side _x) getFriend _sideP) < 0.6) then { // if group is enemy
				_allEnemyG pushBack _x;

				if (((leader _x) distance _vh) < viewDistance) then { // if leader of group is in sight
					if (((_x knowsAbout _vh) max (_x knowsAbout _asVh)) > 1) then { // if group leader knows about me
						_knowAboutMeG pushBack _x;

						{
							if !(captive _x) then { _knowAboutMe pushBack _x };
						} foreach (units _x);
					};
				};
			};
		} foreach allGroups;

		_vehs pushBack [_x,_vh,_asVh,_knowAboutMe,_knowAboutMeG];
	} foreach _units;

	{
		_unit = _x select 0; // variables exactly the same as above
		_vh = _x select 1;
		_asVh = _x select 2;
		_enemies = _x select 3;
		_enemiesG = _x select 4;

		_onFoot = (_unit == _vh);

		// all the conditions that can trigger losing incognito
		_armed = false; // obvious. only matters if on foot.
		_wrongVeh = false; // in a vehicle hostile to the enemy
		_firing = false; // you just fired a gun
		_recognized = false; //

		if ((_onFoot) and {(({!((toLower _x) in ["","throw"])} count [(currentWeapon _unit),(primaryWeapon _unit),(secondaryWeapon _unit)]) > 0)}) then {
			_armed = true
		};

		if !(_armed) then {
			if !(_onFoot) then {
				_side = [_vh] call getTrueVehicleSide;

				{
					if (((side _x) getFriend _side) < 0.6) exitWith { _wrongVeh = true };
				} foreach _allEnemyG;
			};

			if !(_wrongVeh) then {
				if ((time - RYD_INC_Fired) < 10) then { // if its been 10 seconds since you last fired a gun
					_firing = true
				};

				if !(_firing) then {
					_div = 3 + sunOrMoon;
					_safeDst = 80 * RYD_INC_Diff;

					if (_onFoot) then {
						_speed = [0,0,0] distance (velocity _vh);
						_stance = stance _unit;

						switch (_stance) do {
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

						if (_speed > 2.5) then {
							_safeDst = _safeDst * ((_speed - 1.5)^0.45);
						};
					} else {
						_safeDst = 50 * RYD_INC_Diff
					};

					_safeDst = _safeDst - ((_safeDst * (1 - sunOrMoon))/2);

					{
						if ((_x distance _vh) < _safeDst) then {
							if ((_x distance _vh) < (random (_safeDst/_div)) + (random (_safeDst/_div)) + (random (_safeDst/_div)) + (random (_safeDst/_div))) then {
								_flank = [_vh,_x] call isFlanking;

								if !(_flank) then {
									_isLOS = [_x,_vh] call LOSCheck;

									if (_isLOS) then {_recognized = true};
								};
							};
						};

					  if (_recognized) exitWith {}
					} foreach _enemies;
				};
			};
		};

		RYD_INC_Fired = -10; // hack to make the check equal 0

		_unit setVariable ["RYD_INC_Compromised",((_unit getVariable ["RYD_INC_Exposed",false]) or {(_armed) or {(_wrongVeh) or {(_firing) or {(_recognized)}}}})];

		_knownFor = count _enemiesG;

		_unit setVariable ["RYD_INC_Exposed",false];

		if (_unit getVariable ["RYD_INC_Compromised",false]) then {
			if (_knownFor > 0) then {
				_unit setVariable ["RYD_INC_Exposed",true]
			};
		};

		if (_knownFor > 0) then { _knownForAll = _knownFor };

		if !(_unit getVariable ["RYD_INC_Exposed",false]) then {
			_unit setVariable ["RYD_INC_Undercover",true];
		} else {
			_unit setVariable ["RYD_INC_Undercover",false];
		};

	} foreach _vehs;

	_exposed = {(_x getVariable ["RYD_INC_Exposed",false])} count _units;
	_compromised = {((_x getVariable ["RYD_INC_Compromised",false]) and {(_x getVariable ["RYD_INC_Undercover",false])})} count _units;
	_incognito = {(_x getVariable ["RYD_INC_Undercover",false]) and {!(_x getVariable ["RYD_INC_Compromised",false])}} count _units;

	if (_exposed == 0) then {
		{
			_unit = _x;
			_unit setVariable ["RYD_INC_Settings",[behaviour _unit,combatMode _unit]];
			_unit setCombatMode "GREEN";
			_unit setBehaviour "SAFE";
			_unit setCaptive true;
		} foreach _units;
	}	else {
		{
			_unit = _x;

			_unit setVariable ["RYD_INC_Undercover",false];
			_settings = _unit getVariable ["RYD_INC_Settings",["YELLOW","AWARE"]];
			_unit setCombatMode (_settings select 0);
			_unit setBehaviour (_settings select 1);
			_unit setCaptive false
		} foreach _units;
	};

	//hintSilent format ["comp: %1 exp: %2 inc: %3",_compromised,_exposed,_incognito];
	private _txt = "";
	if (RYD_INC_Diff < 1.5) then {
		if (true) then {
			switch (true) do {
				case (_exposed > 0) :
					{	_txt = "You've been exposed!"	};

				case (_incognito > lastIncognito) :
					{
					if ((count _units) == 1) then {
						_txt = "You're now incognito"
					} else {
						if (_incognito == 1) then {
							_txt = "One of you is now incognito"
						} else {
							_txt = format ["The %1 of you are now incognito",_incognito]
						}
					}
				};

				default {
					if ((count _units) > 1) then {
						if (_compromised > 0) then {
							if (lastIncognito > 0) then {
								_txt = format ["Incognito status at risk for %1 of you",_compromised]
							}
						};

						if (RYD_INC_Diff < 1) then {
							if (_knownForAll > 0) then {
								if (_knownForAll == 1) then {
									_txt = _txt + (format ["\nOne of you is being observed",_knownForAll])
								} else {
									_txt = _txt + (format ["\nThe %1 of you are being observed",_knownForAll])
								}
							}
						}
					} else {
						switch (true) do {
							case (_compromised > 0) :
								{ if (lastIncognito > 0) then { _txt = "Incognito status at risk" }; };

							case (_knownForAll > 0) :
								{ if (RYD_INC_Diff < 1) then { _txt = "You're being observed" }; };
						}
					}
				}
			}
		};
		if !(_txt isEqualTo "") then {
			if !(lastTxt isEqualTo _txt) then	{
				hint _txt;
				lastTxt = _txt;
			};
		};
	};

	lastIncognito = _incognito;
}, 4] call CBA_fnc_addPerFrameHandler;
