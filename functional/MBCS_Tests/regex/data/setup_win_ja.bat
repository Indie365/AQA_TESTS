@echo off
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem
rem      https://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

@echo ------------ Pattern matching test ------------

java %JAVA_OPTIONS% SimpleGrep あいうえお %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes "あいうえお". 
@echo --- Did you get the line(s) 11,12 and 47 ?

java %JAVA_OPTIONS% SimpleGrep "あ.*お" %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes the pattern "あ*お". 
@echo --- Did you get the line(s) 11,12,47,48,50 and 52 ?

java %JAVA_OPTIONS% SimpleGrep "^漢" %PWD%\win_ja.txt
@echo --- Confirm that the line(s) starts with "漢".
@echo --- Did you get the line 53,54 and 55 ?

java %JAVA_OPTIONS% SimpleGrep ｶﾅ %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes half-width Katakana "ｶﾅ". 
@echo --- Did you get the line 19,20 and 39 ?

java %JAVA_OPTIONS% SimpleGrep ￥ %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes "￥" (full-width Yen symbol). 
@echo --- Did you get the line 24 and 66 ?

java %JAVA_OPTIONS% SimpleGrep \\ %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes "\" (half-width Yen symbol). 
@echo --- Did you get the line 33 and 35 ?

java %JAVA_OPTIONS% SimpleGrep "鼻.*ソ" %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes the pattern "鼻.*ソ". 
@echo --- Did you get the line 81 ?

java %JAVA_OPTIONS% SimpleGrep \u3042\u304b\u3055 %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes "あかさ". 
@echo --- Did you get the line 31 ?

java %JAVA_OPTIONS% SimpleGrep [�合紫順~�S�X] %PWD%\win_ja.txt
@echo --- Confirm that the line(s) includes any of ��,��,��,�~,�S or �X. 
@echo --- Did you get the line 60,61 and 63 ?


@echo\
@echo ------------ Pattern replacement test ------------

java %JAVA_OPTIONS% RegexReplaceTest あいうえお aiueo %PWD%\win_ja.txt -v
@echo --- Confirm that "あいうえお" was replaced by "aiueo". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest ｶﾅ カタカナ %PWD%\win_ja.txt -v
@echo --- Confirm that "ｶﾅ" was replaced by "カタカナ". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest ￥ \\ %PWD%\win_ja.txt -v
@echo --- Confirm that "￥" was replaced by "\". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest "鼻.*ソ" "５ｃ文字列" %PWD%\win_ja.txt -v
@echo --- Confirm that "鼻.*ソ" was replaced by "５ｃ文字列". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest \u3042\u304b\u3055 ソ躾 %PWD%\win_ja.txt -v
@echo --- Confirm that "あかさ" was replaced by "ソ躾". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest [�合紫順~�S�X] 外字 %PWD%\win_ja.txt -v
@echo --- Confirm that any of "�合紫順~�S�X" were replaced by "外字". 
@echo --- OK ?
