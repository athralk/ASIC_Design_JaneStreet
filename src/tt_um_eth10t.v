module tt_um_eth10t (
    ui_in,
    rst_n,
    clk,
    uio_in,
    ena,
    uo_out,
    uio_out,
    uio_oe
);

    input [7:0] ui_in;
    input rst_n;
    input clk;
    input [7:0] uio_in;
    input ena;
    output [7:0] uo_out;
    output [7:0] uio_out;
    output [7:0] uio_oe;

    wire [7:0] _46;
    wire _187;
    wire _183;
    wire _181;
    wire _184;
    wire _185;
    reg _188;
    wire _173;
    wire [2:0] _150;
    wire _151;
    wire _174;
    wire _175;
    wire _176;
    reg _179;
    wire [1:0] _133;
    wire _130;
    wire _131;
    wire _126;
    wire _132;
    wire _119;
    wire _120;
    wire _109;
    wire _110;
    wire _111;
    wire _112;
    wire _114;
    wire _2;
    reg _103;
    wire _118;
    wire _121;
    wire [7:0] _189;
    wire [7:0] _198;
    wire [7:0] _195;
    wire [7:0] _196;
    wire [7:0] _4;
    reg [7:0] _192;
    wire [6:0] _193;
    wire [7:0] _194;
    wire [7:0] _200;
    wire [7:0] _201;
    wire [7:0] _202;
    wire [7:0] _5;
    reg [7:0] _199;
    wire _254;
    wire _226;
    wire _227;
    wire _255;
    wire _6;
    reg _215;
    wire _279;
    wire _276;
    wire _273;
    wire _274;
    wire _277;
    wire _280;
    wire _7;
    reg _259;
    wire [31:0] _496;
    wire _452;
    wire _450;
    wire _449;
    wire _451;
    wire _453;
    wire _454;
    wire _448;
    wire _455;
    reg _458;
    wire _459;
    wire [31:0] _447;
    wire [31:0] _480;
    wire _466;
    wire [5:0] _169;
    wire _170;
    wire _167;
    wire _168;
    wire _171;
    wire [7:0] _9;
    wire [6:0] _303;
    wire [7:0] _304;
    wire _301;
    wire [7:0] _305;
    wire [7:0] _306;
    wire [7:0] _307;
    wire [7:0] _10;
    reg [7:0] _164;
    wire _165;
    wire _159;
    wire _160;
    wire _156;
    wire _157;
    wire _155;
    wire _158;
    wire _154;
    wire _161;
    wire _153;
    wire _166;
    wire _152;
    wire _172;
    wire _465;
    wire _467;
    wire _468;
    reg _471;
    wire _464;
    wire _472;
    wire [1:0] _473;
    wire [3:0] _474;
    wire [7:0] _475;
    wire [15:0] _476;
    wire [31:0] _477;
    wire [31:0] _463;
    wire [31:0] _478;
    wire [30:0] _461;
    wire [31:0] _462;
    wire [31:0] _479;
    wire _436;
    wire _437;
    wire _434;
    wire _435;
    wire _438;
    wire _439;
    wire _440;
    wire [2:0] _124;
    wire [2:0] _430;
    wire [2:0] _427;
    wire [2:0] _428;
    wire [2:0] _419;
    wire [2:0] _420;
    wire [2:0] _421;
    wire [2:0] _422;
    wire [2:0] _180;
    wire _415;
    reg _418;
    wire [2:0] _423;
    wire [2:0] _424;
    wire [2:0] _425;
    wire _207;
    wire _208;
    wire [2:0] _205;
    wire [2:0] _345;
    wire _346;
    wire [5:0] _343;
    wire [5:0] _128;
    wire [5:0] _404;
    wire [5:0] _396;
    wire [5:0] _397;
    wire [4:0] _263;
    wire [4:0] _261;
    wire [4:0] _349;
    wire [4:0] _351;
    wire [4:0] _333;
    wire _334;
    reg _337;
    wire [4:0] _339;
    wire _251;
    wire [9:0] _242;
    wire [9:0] _240;
    wire [9:0] _311;
    wire [9:0] _312;
    wire [9:0] _313;
    reg _250;
    wire _308;
    wire _309;
    wire _310;
    wire [9:0] _315;
    wire [9:0] _11;
    reg [9:0] _241;
    wire _243;
    reg _246;
    wire _320;
    wire _316;
    wire _318;
    wire _321;
    wire _12;
    reg _237;
    wire _238;
    wire _247;
    wire _252;
    wire [4:0] _341;
    wire [4:0] _331;
    wire [4:0] _327;
    wire [4:0] _328;
    wire [4:0] _329;
    wire [4:0] _332;
    wire [4:0] _342;
    wire [4:0] _352;
    wire [4:0] _13;
    reg [4:0] tx_timer;
    wire _264;
    reg _267;
    wire _145;
    wire _146;
    wire _268;
    reg _271;
    wire _216;
    wire _217;
    reg _220;
    wire _142;
    wire _139;
    wire _136;
    wire _135;
    wire _137;
    wire _140;
    wire _143;
    wire _221;
    reg _224;
    wire [5:0] _387;
    wire _388;
    wire [2:0] _144;
    wire _385;
    wire [2:0] _141;
    wire _384;
    wire _386;
    wire _389;
    reg _392;
    wire [5:0] _358;
    wire [5:0] _370;
    wire _368;
    wire [5:0] _371;
    reg _300;
    wire [5:0] _372;
    wire _356;
    wire _357;
    wire _363;
    reg _366;
    wire [5:0] _373;
    wire [5:0] _374;
    wire [5:0] _376;
    wire [5:0] _14;
    reg [5:0] tx_bytecnt;
    wire _359;
    reg _362;
    wire _379;
    wire _228;
    reg _231;
    reg _234;
    wire _294;
    wire _293;
    wire _295;
    wire _296;
    wire _297;
    wire _377;
    wire [2:0] _289;
    wire [2:0] _288;
    wire _290;
    wire _286;
    wire _285;
    wire _287;
    wire _291;
    wire _283;
    wire _281;
    wire _284;
    wire _292;
    wire _378;
    wire _380;
    reg _383;
    wire _393;
    wire _394;
    wire _395;
    wire [5:0] _399;
    wire [5:0] _400;
    wire [5:0] _402;
    wire [5:0] _405;
    wire [5:0] _15;
    reg [5:0] tx_bitcnt;
    wire _344;
    wire _347;
    wire [2:0] _413;
    wire [2:0] _407;
    wire [2:0] _409;
    wire [2:0] _411;
    wire [2:0] _414;
    wire [2:0] _16;
    reg [2:0] tx_phase;
    wire _206;
    wire _209;
    reg _212;
    wire [2:0] _426;
    wire _204;
    wire [2:0] _429;
    wire _256;
    wire [2:0] _431;
    wire [2:0] _17;
    reg [2:0] tx_state;
    wire _432;
    wire _433;
    wire _441;
    reg _444;
    wire [31:0] _481;
    wire [31:0] _18;
    reg [31:0] _460;
    wire [31:0] _19;
    wire _497;
    wire [1:0] _488;
    wire _108;
    wire [1:0] _489;
    wire [1:0] _490;
    wire _485;
    wire [1:0] _487;
    wire [1:0] _491;
    wire [1:0] _20;
    reg [1:0] rx_check;
    wire _492;
    wire _498;
    wire _500;
    wire _21;
    reg _495;
    wire [2:0] _502;
    wire [2:0] _503;
    wire [2:0] _504;
    wire [2:0] _506;
    wire [2:0] _22;
    reg [2:0] rx_bitidx;
    wire _517;
    wire _518;
    wire _519;
    wire _23;
    reg _515;
    wire _523;
    wire _524;
    wire _24;
    reg _522;
    wire [5:0] _531;
    wire [5:0] _532;
    wire [5:0] _533;
    wire [5:0] _535;
    wire [5:0] _25;
    reg [5:0] _527;
    wire _529;
    wire _539;
    wire [15:0] _325;
    wire [15:0] _323;
    wire [15:0] _536;
    wire [15:0] _537;
    wire [15:0] _26;
    reg [15:0] _324;
    wire _326;
    wire _540;
    wire _542;
    wire _27;
    reg _117;
    wire [7:0] _741;
    wire _588;
    wire _589;
    wire _590;
    wire _28;
    reg _545;
    wire _591;
    wire _592;
    wire _593;
    wire _594;
    reg _597;
    wire _598;
    wire _599;
    wire _600;
    wire _29;
    reg _96;
    reg _99;
    wire _601;
    wire _30;
    reg _92;
    wire _87;
    wire _88;
    wire _81;
    reg _77;
    wire _82;
    wire _89;
    wire _93;
    wire _100;
    wire _738;
    wire _507;
    wire _56;
    wire _55;
    wire _57;
    wire _605;
    wire _606;
    wire _607;
    wire _604;
    wire _608;
    wire _31;
    reg rx_miss;
    wire _68;
    wire _584;
    wire _582;
    wire _580;
    wire _578;
    wire _577;
    wire _579;
    wire _581;
    wire _583;
    wire _585;
    wire _586;
    wire _573;
    wire _571;
    wire _569;
    wire _567;
    wire [11:0] _53;
    wire [2:0] _720;
    wire [8:0] _719;
    wire [11:0] _721;
    wire _716;
    wire [10:0] _715;
    wire [11:0] _717;
    wire [1:0] _713;
    wire [9:0] _712;
    wire [11:0] _714;
    wire [11:0] _718;
    wire [4:0] _674;
    wire _672;
    wire _673;
    wire [5:0] _675;
    wire [4:0] _664;
    wire [5:0] _705;
    wire [5:0] _702;
    wire [4:0] _690;
    wire _688;
    wire _689;
    wire [5:0] _691;
    wire [4:0] _686;
    wire [5:0] _669;
    wire [2:0] _622;
    wire _618;
    wire _619;
    wire _33;
    wire _48;
    wire _612;
    wire _613;
    wire _610;
    wire _614;
    wire _34;
    reg _73;
    wire _70;
    wire _74;
    wire _620;
    wire [2:0] _623;
    wire [2:0] _624;
    wire [2:0] _625;
    wire [2:0] _616;
    wire [2:0] _626;
    wire [2:0] _35;
    reg [2:0] rx_nbits;
    wire _667;
    wire _668;
    wire [5:0] _671;
    wire [5:0] _683;
    wire _684;
    wire _685;
    wire [5:0] _687;
    wire _692;
    wire _693;
    wire _694;
    reg _697;
    wire _698;
    wire [5:0] _700;
    wire _650;
    wire _649;
    wire _651;
    wire _652;
    wire _646;
    wire _645;
    wire _647;
    wire _648;
    wire _653;
    wire _654;
    reg _657;
    wire [5:0] _703;
    wire _637;
    wire _636;
    wire _638;
    wire _639;
    wire _633;
    wire _632;
    wire _634;
    wire _635;
    wire _640;
    wire _641;
    reg _644;
    wire [5:0] _706;
    wire [5:0] _631;
    wire [5:0] _707;
    wire [5:0] _36;
    reg [5:0] rx_vote;
    wire _662;
    wire _663;
    wire [5:0] _665;
    wire _676;
    wire _677;
    wire _659;
    wire _658;
    wire _660;
    wire _661;
    wire _678;
    reg _681;
    wire [11:0] _722;
    wire [11:0] _709;
    wire [11:0] _708;
    wire [11:0] _710;
    wire [11:0] _711;
    wire [11:0] _723;
    wire [11:0] _37;
    reg [11:0] rx_ph;
    wire _566;
    wire _568;
    wire _570;
    wire _572;
    wire _574;
    wire _575;
    wire _587;
    wire _727;
    wire _729;
    wire _725;
    wire _730;
    wire _38;
    reg rx_seen;
    wire _69;
    wire _734;
    wire _735;
    wire _576;
    reg _558;
    reg _561;
    reg _564;
    wire vdd;
    wire _40;
    wire [7:0] _42;
    wire _546;
    reg _549;
    reg _552;
    reg _555;
    wire _565;
    wire _602;
    wire _732;
    wire _736;
    wire _43;
    reg rx_active;
    wire _58;
    reg _61;
    wire _508;
    reg _511;
    wire _512;
    wire _740;
    wire _44;
    reg rx_in_frame;
    wire [7:0] _742;
    assign _46 = 8'b11110011;
    assign _187 = 1'b0;
    assign _183 = _289 == tx_state;
    assign _181 = _180 == tx_state;
    assign _184 = _181 | _183;
    assign _185 = _146 ? _174 : _184;
    always @(posedge _40) begin
        _188 <= _185;
    end
    assign _173 = ~ _172;
    assign _150 = 3'b011;
    assign _151 = tx_phase < _150;
    assign _174 = _151 ? _173 : _172;
    assign _175 = ~ _174;
    assign _176 = _146 & _175;
    always @(posedge _40) begin
        _179 <= _176;
    end
    assign _133 = 2'b00;
    assign _130 = tx_bitcnt[2:2];
    assign _131 = ~ _130;
    assign _126 = _150 == tx_state;
    assign _132 = _126 & _131;
    assign _119 = rx_bitidx[2:2];
    assign _120 = ~ _119;
    assign _109 = 1'b1;
    assign _110 = _108 ? _109 : _103;
    assign _111 = rx_in_frame ? _110 : _103;
    assign _112 = _77 ? _111 : _103;
    assign _114 = _100 ? _187 : _112;
    assign _2 = _114;
    always @(posedge _40) begin
        if (_48)
            _103 <= _187;
        else
            _103 <= _2;
    end
    assign _118 = rx_in_frame & _103;
    assign _121 = _118 & _120;
    assign _189 = { _117,
                    rx_in_frame,
                    _121,
                    _132,
                    _133,
                    _179,
                    _188 };
    assign _198 = 8'b00000000;
    assign _195 = rx_in_frame ? _194 : _192;
    assign _196 = _77 ? _195 : _192;
    assign _4 = _196;
    always @(posedge _40) begin
        _192 <= _4;
    end
    assign _193 = _192[7:1];
    assign _194 = { _99,
                    _193 };
    assign _200 = _108 ? _194 : _199;
    assign _201 = rx_in_frame ? _200 : _199;
    assign _202 = _77 ? _201 : _199;
    assign _5 = _202;
    always @(posedge _40) begin
        _199 <= _5;
    end
    assign _254 = _252 ? _187 : _227;
    assign _226 = _224 ? _109 : _215;
    assign _227 = _212 ? _226 : _215;
    assign _255 = _204 ? _254 : _227;
    assign _6 = _255;
    always @(posedge _40) begin
        if (_48)
            _215 <= _187;
        else
            _215 <= _6;
    end
    assign _279 = _267 ? _109 : _277;
    assign _276 = _252 ? _187 : _274;
    assign _273 = _271 ? _109 : _259;
    assign _274 = _212 ? _273 : _259;
    assign _277 = _204 ? _276 : _274;
    assign _280 = _256 ? _279 : _277;
    assign _7 = _280;
    always @(posedge _40) begin
        if (_48)
            _259 <= _187;
        else
            _259 <= _7;
    end
    assign _496 = 32'b11011110101110110010000011100011;
    assign _452 = _141 == tx_state;
    assign _450 = _205 == tx_state;
    assign _449 = _150 == tx_state;
    assign _451 = _449 | _450;
    assign _453 = _451 | _452;
    assign _454 = _206 & _453;
    assign _448 = _77 & rx_in_frame;
    assign _455 = _438 ? _454 : _448;
    always @(posedge _40) begin
        _458 <= _455;
    end
    assign _459 = _444 | _458;
    assign _447 = 32'b00000000000000000000000000000000;
    assign _480 = 32'b11111111111111111111111111111111;
    assign _466 = _19[0:0];
    assign _169 = 6'b111111;
    assign _170 = tx_bitcnt == _169;
    assign _167 = tx_bitcnt[0:0];
    assign _168 = ~ _167;
    assign _171 = _168 | _170;
    assign _9 = ui_in;
    assign _303 = _164[7:1];
    assign _304 = { _187,
                    _303 };
    assign _301 = _150 == tx_state;
    assign _305 = _301 ? _304 : _164;
    assign _306 = _300 ? _9 : _305;
    assign _307 = _212 ? _306 : _164;
    assign _10 = _307;
    always @(posedge _40) begin
        _164 <= _10;
    end
    assign _165 = _164[0:0];
    assign _159 = _19[0:0];
    assign _160 = ~ _159;
    assign _156 = tx_bitcnt[0:0];
    assign _157 = ~ _156;
    assign _155 = _144 == tx_state;
    assign _158 = _155 & _157;
    assign _154 = _141 == tx_state;
    assign _161 = _154 ? _160 : _158;
    assign _153 = _150 == tx_state;
    assign _166 = _153 ? _165 : _161;
    assign _152 = _345 == tx_state;
    assign _172 = _152 ? _171 : _166;
    assign _465 = _141 == tx_state;
    assign _467 = _465 ? _466 : _172;
    assign _468 = _438 ? _467 : _99;
    always @(posedge _40) begin
        _471 <= _468;
    end
    assign _464 = _460[0:0];
    assign _472 = _464 ^ _471;
    assign _473 = { _472,
                    _472 };
    assign _474 = { _473,
                    _473 };
    assign _475 = { _474,
                    _474 };
    assign _476 = { _475,
                    _475 };
    assign _477 = { _476,
                    _476 };
    assign _463 = 32'b11101101101110001000001100100000;
    assign _478 = _463 & _477;
    assign _461 = _460[31:1];
    assign _462 = { _187,
                    _461 };
    assign _479 = _462 ^ _478;
    assign _436 = _180 == tx_state;
    assign _437 = ~ _436;
    assign _434 = _124 == tx_state;
    assign _435 = ~ _434;
    assign _438 = _435 & _437;
    assign _439 = ~ _438;
    assign _440 = _100 & _439;
    assign _124 = 3'b000;
    assign _430 = _347 ? _124 : _429;
    assign _427 = _337 ? _180 : _426;
    assign _428 = _252 ? _345 : _427;
    assign _419 = _300 ? _150 : tx_state;
    assign _420 = _366 ? _205 : _419;
    assign _421 = _383 ? _141 : _420;
    assign _422 = _392 ? _289 : _421;
    assign _180 = 3'b001;
    assign _415 = _180 == tx_state;
    always @(posedge _40) begin
        if (_206)
            _418 <= _415;
    end
    assign _423 = _418 ? _124 : _422;
    assign _424 = _224 ? _144 : _423;
    assign _425 = _271 ? _289 : _424;
    assign _207 = _124 == tx_state;
    assign _208 = ~ _207;
    assign _205 = 3'b100;
    assign _345 = 3'b010;
    assign _346 = tx_phase == _345;
    assign _343 = 6'b000010;
    assign _128 = 6'b000000;
    assign _404 = _267 ? _128 : _402;
    assign _396 = 6'b000001;
    assign _397 = tx_bitcnt + _396;
    assign _263 = 5'b11111;
    assign _261 = 5'b00000;
    assign _349 = _347 ? _261 : _342;
    assign _351 = _267 ? _261 : _349;
    assign _333 = 5'b01111;
    assign _334 = tx_timer == _333;
    always @(posedge _40) begin
        _337 <= _334;
    end
    assign _339 = _337 ? _261 : _332;
    assign _251 = ~ _250;
    assign _242 = 10'b1001000000;
    assign _240 = 10'b0000000000;
    assign _311 = 10'b0000000001;
    assign _312 = _241 + _311;
    assign _313 = _246 ? _241 : _312;
    always @(posedge _40) begin
        _250 <= rx_active;
    end
    assign _308 = _124 == tx_state;
    assign _309 = ~ _308;
    assign _310 = _309 | _250;
    assign _315 = _310 ? _240 : _313;
    assign _11 = _315;
    always @(posedge _40) begin
        if (_48)
            _241 <= _240;
        else
            _241 <= _11;
    end
    assign _243 = _241 == _242;
    always @(posedge _40) begin
        _246 <= _243;
    end
    assign _320 = _252 ? _187 : _318;
    assign _316 = ~ _234;
    assign _318 = _316 ? _109 : _237;
    assign _321 = _204 ? _320 : _318;
    assign _12 = _321;
    always @(posedge _40) begin
        if (_48)
            _237 <= _187;
        else
            _237 <= _12;
    end
    assign _238 = _234 & _237;
    assign _247 = _238 & _246;
    assign _252 = _247 & _251;
    assign _341 = _252 ? _261 : _339;
    assign _331 = _271 ? _261 : _329;
    assign _327 = 5'b00001;
    assign _328 = tx_timer + _327;
    assign _329 = _326 ? _328 : tx_timer;
    assign _332 = _212 ? _331 : _329;
    assign _342 = _204 ? _341 : _332;
    assign _352 = _256 ? _351 : _342;
    assign _13 = _352;
    always @(posedge _40) begin
        if (_48)
            tx_timer <= _261;
        else
            tx_timer <= _13;
    end
    assign _264 = tx_timer == _263;
    always @(posedge _40) begin
        _267 <= _264;
    end
    assign _145 = _144 == tx_state;
    assign _146 = _143 | _145;
    assign _268 = _146 & _267;
    always @(posedge _40) begin
        if (_206)
            _271 <= _268;
    end
    assign _216 = rx_nbits[2:2];
    assign _217 = rx_active & _216;
    always @(posedge _40) begin
        _220 <= _217;
    end
    assign _142 = _141 == tx_state;
    assign _139 = _205 == tx_state;
    assign _136 = _150 == tx_state;
    assign _135 = _345 == tx_state;
    assign _137 = _135 | _136;
    assign _140 = _137 | _139;
    assign _143 = _140 | _142;
    assign _221 = _143 & _220;
    always @(posedge _40) begin
        if (_206)
            _224 <= _221;
    end
    assign _387 = 6'b011111;
    assign _388 = tx_bitcnt == _387;
    assign _144 = 3'b110;
    assign _385 = _144 == tx_state;
    assign _141 = 3'b101;
    assign _384 = _141 == tx_state;
    assign _386 = _384 | _385;
    assign _389 = _386 & _388;
    always @(posedge _40) begin
        if (_206)
            _392 <= _389;
    end
    assign _358 = 6'b111100;
    assign _370 = tx_bytecnt + _396;
    assign _368 = tx_bytecnt == _358;
    assign _371 = _368 ? tx_bytecnt : _370;
    always @(posedge _40) begin
        if (_206)
            _300 <= _297;
    end
    assign _372 = _300 ? _371 : tx_bytecnt;
    assign _356 = ~ _297;
    assign _357 = _292 & _356;
    assign _363 = _357 & _362;
    always @(posedge _40) begin
        if (_206)
            _366 <= _363;
    end
    assign _373 = _366 ? _371 : _372;
    assign _374 = _212 ? _373 : tx_bytecnt;
    assign _376 = _204 ? _128 : _374;
    assign _14 = _376;
    always @(posedge _40) begin
        if (_48)
            tx_bytecnt <= _128;
        else
            tx_bytecnt <= _14;
    end
    assign _359 = tx_bytecnt < _358;
    always @(posedge _40) begin
        _362 <= _359;
    end
    assign _379 = ~ _362;
    assign _228 = _42[3:3];
    always @(posedge _40) begin
        _231 <= _228;
    end
    always @(posedge _40) begin
        _234 <= _231;
    end
    assign _294 = _150 == tx_state;
    assign _293 = _345 == tx_state;
    assign _295 = _293 | _294;
    assign _296 = _292 & _295;
    assign _297 = _296 & _234;
    assign _377 = ~ _297;
    assign _289 = 3'b111;
    assign _288 = tx_bitcnt[2:0];
    assign _290 = _288 == _289;
    assign _286 = _205 == tx_state;
    assign _285 = _150 == tx_state;
    assign _287 = _285 | _286;
    assign _291 = _287 & _290;
    assign _283 = tx_bitcnt == _169;
    assign _281 = _345 == tx_state;
    assign _284 = _281 & _283;
    assign _292 = _284 | _291;
    assign _378 = _292 & _377;
    assign _380 = _378 & _379;
    always @(posedge _40) begin
        if (_206)
            _383 <= _380;
    end
    assign _393 = _383 | _392;
    assign _394 = _393 | _224;
    assign _395 = _394 | _271;
    assign _399 = _395 ? _128 : _397;
    assign _400 = _212 ? _399 : tx_bitcnt;
    assign _402 = _204 ? _128 : _400;
    assign _405 = _256 ? _404 : _402;
    assign _15 = _405;
    always @(posedge _40) begin
        if (_48)
            tx_bitcnt <= _128;
        else
            tx_bitcnt <= _15;
    end
    assign _344 = tx_bitcnt == _343;
    assign _347 = _344 & _346;
    assign _413 = _347 ? _124 : _411;
    assign _407 = tx_phase + _180;
    assign _409 = _212 ? _124 : _407;
    assign _411 = _204 ? _124 : _409;
    assign _414 = _256 ? _413 : _411;
    assign _16 = _414;
    always @(posedge _40) begin
        if (_48)
            tx_phase <= _124;
        else
            tx_phase <= _16;
    end
    assign _206 = tx_phase == _205;
    assign _209 = _206 & _208;
    always @(posedge _40) begin
        _212 <= _209;
    end
    assign _426 = _212 ? _425 : tx_state;
    assign _204 = _124 == tx_state;
    assign _429 = _204 ? _428 : _426;
    assign _256 = _289 == tx_state;
    assign _431 = _256 ? _430 : _429;
    assign _17 = _431;
    always @(posedge _40) begin
        if (_48)
            tx_state <= _124;
        else
            tx_state <= _17;
    end
    assign _432 = _124 == tx_state;
    assign _433 = _432 & _252;
    assign _441 = _433 | _440;
    always @(posedge _40) begin
        _444 <= _441;
    end
    assign _481 = _444 ? _480 : _479;
    assign _18 = _481;
    always @(posedge _40) begin
        if (_459)
            _460 <= _18;
    end
    assign _19 = _460;
    assign _497 = _19 == _496;
    assign _488 = 2'b01;
    assign _108 = rx_bitidx == _289;
    assign _489 = _108 ? _488 : _487;
    assign _490 = rx_in_frame ? _489 : _487;
    assign _485 = rx_check[0:0];
    assign _487 = { _485,
                    _187 };
    assign _491 = _77 ? _490 : _487;
    assign _20 = _491;
    always @(posedge _40) begin
        if (_48)
            rx_check <= _133;
        else
            rx_check <= _20;
    end
    assign _492 = rx_check[1:1];
    assign _498 = _492 ? _497 : _495;
    assign _500 = _100 ? _187 : _498;
    assign _21 = _500;
    always @(posedge _40) begin
        if (_48)
            _495 <= _187;
        else
            _495 <= _21;
    end
    assign _502 = rx_bitidx + _180;
    assign _503 = rx_in_frame ? _502 : rx_bitidx;
    assign _504 = _77 ? _503 : rx_bitidx;
    assign _506 = _100 ? _124 : _504;
    assign _22 = _506;
    always @(posedge _40) begin
        if (_48)
            rx_bitidx <= _124;
        else
            rx_bitidx <= _22;
    end
    assign _517 = rx_bitidx == _124;
    assign _518 = ~ _517;
    assign _519 = _512 ? _518 : _515;
    assign _23 = _519;
    always @(posedge _40) begin
        if (_48)
            _515 <= _187;
        else
            _515 <= _23;
    end
    assign _523 = ~ _522;
    assign _524 = _512 ? _523 : _522;
    assign _24 = _524;
    always @(posedge _40) begin
        if (_48)
            _522 <= _187;
        else
            _522 <= _24;
    end
    assign _531 = _527 + _396;
    assign _532 = _529 ? _527 : _531;
    assign _533 = _326 ? _532 : _527;
    assign _535 = _511 ? _128 : _533;
    assign _25 = _535;
    always @(posedge _40) begin
        if (_48)
            _527 <= _128;
        else
            _527 <= _25;
    end
    assign _529 = _527 == _169;
    assign _539 = _529 ? _187 : _117;
    assign _325 = 16'b1111111111111111;
    assign _323 = 16'b0000000000000000;
    assign _536 = 16'b0000000000000001;
    assign _537 = _324 + _536;
    assign _26 = _537;
    always @(posedge _40) begin
        if (_48)
            _324 <= _323;
        else
            _324 <= _26;
    end
    assign _326 = _324 == _325;
    assign _540 = _326 ? _539 : _117;
    assign _542 = _511 ? _109 : _540;
    assign _27 = _542;
    always @(posedge _40) begin
        if (_48)
            _117 <= _187;
        else
            _117 <= _27;
    end
    assign _741 = { _117,
                    _522,
                    _515,
                    _495,
                    _259,
                    _215,
                    _217,
                    _438 };
    assign _588 = _586 ? _552 : _564;
    assign _589 = _587 ? _588 : _545;
    assign _590 = rx_active ? _589 : _545;
    assign _28 = _590;
    always @(posedge _40) begin
        if (_48)
            _545 <= _187;
        else
            _545 <= _28;
    end
    assign _591 = rx_ph[3:3];
    assign _592 = _591 ? _564 : _552;
    assign _593 = rx_seen ? _545 : _592;
    assign _594 = _575 ? _564 : _593;
    always @(posedge _40) begin
        _597 <= _594;
    end
    assign _598 = _69 ? _597 : _96;
    assign _599 = _61 ? _598 : _96;
    assign _600 = rx_active ? _599 : _96;
    assign _29 = _600;
    always @(posedge _40) begin
        if (_48)
            _96 <= _187;
        else
            _96 <= _29;
    end
    always @(posedge _40) begin
        _99 <= _96;
    end
    assign _601 = _77 ? _99 : _92;
    assign _30 = _601;
    always @(posedge _40) begin
        if (_48)
            _92 <= _187;
        else
            _92 <= _30;
    end
    assign _87 = rx_nbits < _205;
    assign _88 = ~ _87;
    assign _81 = ~ rx_in_frame;
    always @(posedge _40) begin
        _77 <= _74;
    end
    assign _82 = _77 & _81;
    assign _89 = _82 & _88;
    assign _93 = _89 & _92;
    assign _100 = _93 & _99;
    assign _738 = _100 ? _109 : rx_in_frame;
    assign _507 = ~ _69;
    assign _56 = rx_ph[3:3];
    assign _55 = rx_ph[2:2];
    assign _57 = _55 | _56;
    assign _605 = ~ rx_seen;
    assign _606 = _69 ? _605 : rx_miss;
    assign _607 = _61 ? _606 : rx_miss;
    assign _604 = _602 ? _187 : rx_miss;
    assign _608 = rx_active ? _607 : _604;
    assign _31 = _608;
    always @(posedge _40) begin
        if (_48)
            rx_miss <= _187;
        else
            rx_miss <= _31;
    end
    assign _68 = ~ rx_miss;
    assign _584 = rx_ph[1:1];
    assign _582 = rx_ph[0:0];
    assign _580 = rx_ph[9:9];
    assign _578 = rx_ph[10:10];
    assign _577 = rx_ph[11:11];
    assign _579 = _577 | _578;
    assign _581 = _579 | _580;
    assign _583 = _581 | _582;
    assign _585 = _583 | _584;
    assign _586 = _576 & _585;
    assign _573 = rx_ph[2:2];
    assign _571 = rx_ph[1:1];
    assign _569 = rx_ph[10:10];
    assign _567 = rx_ph[11:11];
    assign _53 = 12'b000000000000;
    assign _720 = rx_ph[11:9];
    assign _719 = rx_ph[8:0];
    assign _721 = { _719,
                    _720 };
    assign _716 = rx_ph[11:11];
    assign _715 = rx_ph[10:0];
    assign _717 = { _715,
                    _716 };
    assign _713 = rx_ph[11:10];
    assign _712 = rx_ph[9:0];
    assign _714 = { _712,
                    _713 };
    assign _718 = _697 ? _717 : _714;
    assign _674 = _671[4:0];
    assign _672 = _671[5:5];
    assign _673 = ~ _672;
    assign _675 = { _673,
                    _674 };
    assign _664 = rx_vote[4:0];
    assign _705 = _700 + _396;
    assign _702 = _700 - _396;
    assign _690 = rx_vote[4:0];
    assign _688 = rx_vote[5:5];
    assign _689 = ~ _688;
    assign _691 = { _689,
                    _690 };
    assign _686 = _683[4:0];
    assign _669 = 6'b010000;
    assign _622 = rx_nbits + _180;
    assign _618 = rx_nbits == _289;
    assign _619 = ~ _618;
    assign _33 = rst_n;
    assign _48 = ~ _33;
    assign _612 = _69 ? _109 : _73;
    assign _613 = _61 ? _612 : _73;
    assign _610 = _602 ? _187 : _73;
    assign _614 = rx_active ? _613 : _610;
    assign _34 = _614;
    always @(posedge _40) begin
        if (_48)
            _73 <= _187;
        else
            _73 <= _34;
    end
    assign _70 = _61 & _69;
    assign _74 = _70 & _73;
    assign _620 = _74 & _619;
    assign _623 = _620 ? _622 : rx_nbits;
    assign _624 = _69 ? _623 : rx_nbits;
    assign _625 = _61 ? _624 : rx_nbits;
    assign _616 = _602 ? _124 : rx_nbits;
    assign _626 = rx_active ? _625 : _616;
    assign _35 = _626;
    always @(posedge _40) begin
        if (_48)
            rx_nbits <= _124;
        else
            rx_nbits <= _35;
    end
    assign _667 = rx_nbits == _289;
    assign _668 = ~ _667;
    assign _671 = _668 ? _396 : _669;
    assign _683 = _128 - _671;
    assign _684 = _683[5:5];
    assign _685 = ~ _684;
    assign _687 = { _685,
                    _686 };
    assign _692 = _687 < _691;
    assign _693 = ~ _692;
    assign _694 = _661 & _693;
    always @(posedge _40) begin
        _697 <= _694;
    end
    assign _698 = _681 | _697;
    assign _700 = _698 ? _128 : rx_vote;
    assign _650 = rx_ph[1:1];
    assign _649 = rx_ph[0:0];
    assign _651 = _649 | _650;
    assign _652 = _576 & _651;
    assign _646 = rx_ph[2:2];
    assign _645 = rx_ph[1:1];
    assign _647 = _645 | _646;
    assign _648 = _565 & _647;
    assign _653 = _648 | _652;
    assign _654 = rx_active & _653;
    always @(posedge _40) begin
        _657 <= _654;
    end
    assign _703 = _657 ? _702 : _700;
    assign _637 = rx_ph[9:9];
    assign _636 = rx_ph[10:10];
    assign _638 = _636 | _637;
    assign _639 = _576 & _638;
    assign _633 = rx_ph[10:10];
    assign _632 = rx_ph[11:11];
    assign _634 = _632 | _633;
    assign _635 = _565 & _634;
    assign _640 = _635 | _639;
    assign _641 = rx_active & _640;
    always @(posedge _40) begin
        _644 <= _641;
    end
    assign _706 = _644 ? _705 : _703;
    assign _631 = _602 ? _128 : rx_vote;
    assign _707 = rx_active ? _706 : _631;
    assign _36 = _707;
    always @(posedge _40) begin
        if (_48)
            rx_vote <= _128;
        else
            rx_vote <= _36;
    end
    assign _662 = rx_vote[5:5];
    assign _663 = ~ _662;
    assign _665 = { _663,
                    _664 };
    assign _676 = _665 < _675;
    assign _677 = ~ _676;
    assign _659 = rx_ph[5:5];
    assign _658 = rx_ph[4:4];
    assign _660 = _658 | _659;
    assign _661 = rx_active & _660;
    assign _678 = _661 & _677;
    always @(posedge _40) begin
        _681 <= _678;
    end
    assign _722 = _681 ? _721 : _718;
    assign _709 = 12'b000000000100;
    assign _708 = 12'b000000000010;
    assign _710 = _565 ? _709 : _708;
    assign _711 = _602 ? _710 : rx_ph;
    assign _723 = rx_active ? _722 : _711;
    assign _37 = _723;
    always @(posedge _40) begin
        if (_48)
            rx_ph <= _53;
        else
            rx_ph <= _37;
    end
    assign _566 = rx_ph[0:0];
    assign _568 = _566 | _567;
    assign _570 = _568 | _569;
    assign _572 = _570 | _571;
    assign _574 = _572 | _573;
    assign _575 = _565 & _574;
    assign _587 = _575 | _586;
    assign _727 = _587 ? _109 : rx_seen;
    assign _729 = _61 ? _187 : _727;
    assign _725 = _602 ? _109 : rx_seen;
    assign _730 = rx_active ? _729 : _725;
    assign _38 = _730;
    always @(posedge _40) begin
        if (_48)
            rx_seen <= _187;
        else
            rx_seen <= _38;
    end
    assign _69 = rx_seen | _68;
    assign _734 = _69 ? rx_active : _187;
    assign _735 = _61 ? _734 : rx_active;
    assign _576 = _564 ^ _552;
    always @(negedge _40) begin
        _558 <= _546;
    end
    always @(posedge _40) begin
        _561 <= _558;
    end
    always @(posedge _40) begin
        _564 <= _561;
    end
    assign vdd = 1'b1;
    assign _40 = clk;
    assign _42 = uio_in;
    assign _546 = _42[2:2];
    always @(posedge _40) begin
        _549 <= _546;
    end
    always @(posedge _40) begin
        _552 <= _549;
    end
    always @(posedge _40) begin
        _555 <= _552;
    end
    assign _565 = _555 ^ _564;
    assign _602 = _565 | _576;
    assign _732 = _602 ? _109 : rx_active;
    assign _736 = rx_active ? _735 : _732;
    assign _43 = _736;
    always @(posedge _40) begin
        if (_48)
            rx_active <= _187;
        else
            rx_active <= _43;
    end
    assign _58 = rx_active & _57;
    always @(posedge _40) begin
        _61 <= _58;
    end
    assign _508 = _61 & _507;
    always @(posedge _40) begin
        _511 <= _508;
    end
    assign _512 = _511 & rx_in_frame;
    assign _740 = _512 ? _187 : _738;
    assign _44 = _740;
    always @(posedge _40) begin
        if (_48)
            rx_in_frame <= _187;
        else
            rx_in_frame <= _44;
    end
    assign _742 = rx_in_frame ? _199 : _741;
    assign uo_out = _742;
    assign uio_out = _189;
    assign uio_oe = _46;

endmodule
