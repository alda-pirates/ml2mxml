(**************************************************************************)
(*  Copyright 2015, Ion Alberdi <nolaridebi at gmail.com>                 *)
(*                                                                        *)
(*  Licensed under the Apache License, Version 2.0 (the "License");       *)
(*  you may not use this file except in compliance with the License.      *)
(*  You may obtain a copy of the License at                               *)
(*                                                                        *)
(*      http://www.apache.org/licenses/LICENSE-2.0                        *)
(*                                                                        *)
(*  Unless required by applicable law or agreed to in writing, software   *)
(*  distributed under the License is distributed on an "AS IS" BASIS,     *)
(*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or       *)
(*  implied.  See the License for the specific language governing         *)
(*  permissions and limitations under the License.                        *)
(**************************************************************************)
open Cow

let join join_str l =
  List.fold_left (fun accum elt ->
    match accum with
      | "" -> elt
      | _ -> accum ^ join_str ^ elt) "" l

let decl = join "\n" ["<?xml version=\"1.0\" encoding=\"UTF-8\" ?>";
                      "<!DOCTYPE score-partwise PUBLIC '-//Recordare//DTD MusicXML 2.0 Partwise//EN' 'http://www.musicxml.org/dtds/2.0/partwise.dtd'>";
                      ""]

let create_title title =
  <:xml<
  <movement-title>$str:title$</movement-title>
  >>

let create_date ?(name="find it") date =
  <:xml<
  <identification>
    <encoding>
      <encoding-date>$str:date$</encoding-date>
      <software>$str:name$</software>
    </encoding>
  </identification>
  >>

module Mode = struct
  let to_string x =
    match x with
      | `Major -> "major"
end

module Sign = struct
  let to_string x =
    match x with
    | `Tab -> "TAB"
    | `F -> "F"
    | `G -> "G"
    | `Drum -> "percussion"

  let to_line x =
    (* http://www.musicxml.com/UserManuals/MusicXML/MusicXML.htm#EL-MusicXML-clef.htm *)
    match x with
    | `Tab -> 5
    | `F -> 4
    | `G -> 2
    | `Drum -> assert(false)

end

let create_key fifhts mode =
  <:xml<
  <key>
  <fifths>$int:fifhts$</fifths>
  <mode>$str:Mode.to_string mode$</mode>
  </key>
  >>

let create_time nb_beats beat_type =
  <:xml<
  <time>
  <beats>$int:nb_beats$</beats>
  <beat-type>$int:beat_type$</beat-type>
  </time>
  >>

let create_clef sign number =
  let attrlist = ["number", Printf.sprintf "%d" number] in
  <:xml<
   <clef $alist:attrlist$>
   <sign>$str:Sign.to_string sign$</sign>
   <line>$int:Sign.to_line sign$</line>
   </clef>
  >>

let drum_clef =
  <:xml<
   <clef>
   <sign>percussion</sign>
   </clef>
   >>

let instrument_clef_to_clef x =
  match x with
  | `F -> `F
  | `G -> `G
  | `Drum -> `Drum

module DiatonicScaleStepToTuningStep = struct
  let sharp_flat_to_int x =
    match x with
      | `Sharp -> 1
      | `Flat -> 1

  let note_to_string_alter x =
      match x with
        | `A -> ("A", None)
        | `ASharp -> ("A", Some `Sharp)
        | `B -> ("B", None)
        | `C -> ("C", None)
        | `CSharp -> ("C", Some `Sharp)
        | `D -> ("D", None)
        | `DSharp -> ("D", Some `Sharp)
        | `E -> ("E", None)
        | `F -> ("F", None)
        | `FSharp -> ("F", Some `Sharp)
        | `G -> ("G", None)
        | `GSharp -> ("G", Some `Sharp)

  let to_music_xml x =
    let note_str, sharp_flato = note_to_string_alter x in
    let step = <:xml<
      <tuning-step>$str:note_str$</tuning-step>
      >> in
    let l = [step] in
    match sharp_flato with
      | None -> l
      | Some sharp_flat ->
        let new_elt = <:xml<
          <tuning-alter>$int:sharp_flat_to_int sharp_flat></tuning-alter>
          >> in
        List.rev (new_elt :: l)
end


let create_instrument_staff_lines instrument =
  let open Music in
  let l = Array.to_list instrument.strings in
  let num_lines = List.length l in
  let make_staff_tuning idx step octave =
    let attrs = ["line", Printf.sprintf "%d" (idx + 1)] in
    <:xml<
    <staff-tuning $alist:attrs$>
      $list:(DiatonicScaleStepToTuningStep.to_music_xml step)$
      <tuning-octave>$int:octave$</tuning-octave>
    </staff-tuning>
    >>
  in
  let staff_details =   List.map
    (fun (idx, elt) ->
      make_staff_tuning idx elt.Diatonic.note elt.Diatonic.octave)
    (enumerate l)
  in
  <:xml<
  <staff-details>
    <staff-lines>$int:num_lines$</staff-lines>
    $list:staff_details$
  </staff-details>
  >>

let create_transpose diatonic chromatic octave_change =
  <:xml<
    <transpose>
    <diatonic>$int:diatonic$</diatonic>
    <chromatic>$int:chromatic$</chromatic>
    <octave-change>$int:octave_change$</octave-change>
  </transpose>
   >>

let create_divisions number =
  <:xml<
    <divisions>$int:number$</divisions>
   >>

module BeatUnit = struct
  let to_string x =
    match x with
      | `Quarter -> "quarter"
end

let create_metronome ?(default_y=40) ?(beat_unit=`Quarter) bpm =
  <:xml<
   <direction $alist:[("directive", "yes"); ("placement", "above")]$>
    <direction-type>
     <metronome $alist:[("default-y", Printf.sprintf "%d" default_y); ("parentheses","yes")]$>
      <beat-unit>$str:BeatUnit.to_string beat_unit$</beat-unit>
      <per-minute>$int:bpm$</per-minute>
     </metronome>
    </direction-type>
    <sound $alist:["tempo", Printf.sprintf "%d" bpm]$/>
   </direction>
  >>

let _tie_to_xml f tiedo =
  match tiedo with
  | None -> []
  | Some x ->
     let a =
       match x with
       | `Start -> "start"
       | `Stop -> "stop"
     in
     [f a]

let tied_to_xml =
  _tie_to_xml (fun a ->
               <:xml<
                <tied $alist:["type", a]$/>
                >>)

let tie_to_xml =
  _tie_to_xml (fun a ->
               <:xml<
                <tie $alist:["type", a]$/>
                >>)

let create_pitch step octave sharp_or_flat =
  let r = <:xml<
     <step>$str:step$</step>
    >>
  in
  let r = [r] in
  let r = match sharp_or_flat with
    | None -> r
    | Some alter ->
      let s = DiatonicScaleStepToTuningStep.sharp_flat_to_int alter in
      let elt = <:xml<
        <alter>$int:s$</alter>
        >> in
      List.rev (elt :: r)
  in
  <:xml<
  <pitch>
    $list:r$
    <octave>$int:octave$</octave>
  </pitch>
    >>

let create_notations tied sfo =
  let tied = tied_to_xml tied in
  let technical = match sfo with
    | None -> []
    | Some (s, f) ->
       let elt =
         <:xml<
          <technical>
           <string>$int:s$</string>
           <fret>$int:f$</fret>
          </technical>
          >> in
       [elt]
  in
  <:xml<
   <notations>
   $list:technical$
   $list:tied$
   </notations>
  >>


let create_pitch_and_notations step octave sharp_or_flat tied sfo =
  let pitch = create_pitch step octave sharp_or_flat in
  let notations = create_notations tied sfo in
  pitch, [notations]

let create_string_pitch_and_notations instrument played_note tied =
  let open Music in
  let string = played_note.string in
  let string_empty_note = instrument.strings.(string) in
  let diatonic = Diatonic.shift_n_semitone string_empty_note played_note.fret in
  let step, sharp_or_flat = DiatonicScaleStepToTuningStep.note_to_string_alter diatonic.Diatonic.note in
  (* XXX when guitar pro opens a music_xml it seems
     the string numbers are upside down *)
  let number_strings = Array.length instrument.strings in
  let curr_string = number_strings - played_note.string in
  create_pitch_and_notations step diatonic.Diatonic.octave sharp_or_flat tied (Some (curr_string,
                                                                                     played_note.fret))


let duration_to_string dur =
  match dur with
  | `Sixteenth -> "16th"
  | `Eighth -> "eighth"
  | `Quarter -> "quarter"
  | `Half -> "half"
  | `Whole -> "whole"

(* we hardcode that value to 24
   we create all the duration to
   http://www.musicxml.com/tutorial/the-midi-compatible-part/attributes/ *)
let number_of_divions_per_quarter_note = 24

let duration_to_duration dur =
  match dur with
  | `Sixteenth -> 6
  | `Eighth -> 12
  | `Quarter -> 24
  | `Half -> 48
  | `Whole -> 96

let time_modification meter =
  match meter with
  | `Duple -> []
  | `Triple ->
     let elt =
       <:xml<
        <time-modification>
        <actual-notes>3</actual-notes>
        <normal-notes>2</normal-notes>
        </time-modification>
        >>
     in [elt]

module Constants = struct
    let rest = <:xml<
                <rest/>
                >>
    let chord = <:xml<
                 <chord/>
                 >>
  end

let create_chord_elt_if_necessary is_chord_necessary =
  if is_chord_necessary then [Constants.chord]
  else []

let create_dot_if_necessary dot =
  if dot then
    let elm = <:xml<
               <dot/>
               >> in [elm]
  else []

let create_mxml_note chord
                     pitch_or_rest
                     instrument_lines
                     notations
                     note =
  let open Music in
  let meter = time_modification note.meter in
  <:xml<
   <note>
    $pitch_or_rest$
    $list:create_chord_elt_if_necessary chord$
    <duration>$int:duration_to_duration note.duration$</duration>
    $list:instrument_lines$
    $list:tie_to_xml note.tied$
    $list:create_dot_if_necessary note.dot$
    <voice>1</voice>
    <type>$str:duration_to_string note.duration$</type>
    $list:meter$
    <stem>up</stem>
    $list:notations$
   </note>
   >>

let create_drum_note ?(chord=false) id note =
  let open Music in
  let pitch_or_rest, notations, lines = match note.note with
    | `Rest -> Constants.rest, [], []
    | `Played x ->
       let unpitched = Drum_music_xml.drum_element_to_unpitched x in
       let notehead = Drum_music_xml.drum_element_to_notehead x in
       let tied = tied_to_xml note.tied in
       let empty_notation = <:xml<
                             <notations>
                             <technical/>
                             $list:tied$
                             </notations>
                             >> in
       let instrument_line = Drum_music_xml.drum_element_to_instrument_line
                               id x in

       unpitched, [notehead; empty_notation], [instrument_line]
  in
  create_mxml_note chord pitch_or_rest lines notations note

let create_string_note ?(chord=false) instrument note =
  let open Music in
  let pitch_or_rest, notations = match note.note with
    | `Rest -> Constants.rest, []
    | `Played x -> create_string_pitch_and_notations instrument x note.tied
  in
  create_mxml_note chord pitch_or_rest [] notations note

let create_voice_note ?(chord=false) id note =
  let open Music in
  let pitch_or_rest, notations = match note.note with
    | `Rest -> Constants.rest, []
    | `Played x ->
       let step, sharp_or_flat = DiatonicScaleStepToTuningStep.note_to_string_alter x.Diatonic.note in
       create_pitch_and_notations step x.Diatonic.octave sharp_or_flat note.tied None
  in
  create_mxml_note chord pitch_or_rest [] notations note

let transform_note note newnote =
  let open Music in
  {
    note=newnote;
    duration=note.duration;
    meter=note.meter;
    tied=note.tied;
    dot=note.dot;
  }

let create_measure ?(tempo=None)
                   measure_number
                   notes
                   create_first_note
                   create_chord_note
                   clef
                   additional_first_attributes =
  let notes = List.map (fun note ->
                        match note.Music.note with
                        | `Single x -> [create_first_note
                                          (transform_note note (`Played x))]
                        | `Rest -> [create_first_note
                                      (transform_note note `Rest)]
                        | `Chord l ->
                           let newl = List.map (fun x -> transform_note note (`Played x)) l in
                           let first = List.hd newl in
                           let others = List.tl newl in
                           let first_note = create_first_note first in
                        let other_notes = List.map (fun note -> create_chord_note note)
                                                   others
                        in
                        first_note :: other_notes) notes in
  let notes = List.fold_left (fun accum elt -> accum @ elt) [] notes in
  let is_first_measure = measure_number = 0 in
  let attribute = clef in
  let other_attributes =
    if is_first_measure then
      [create_divisions number_of_divions_per_quarter_note;
       create_time 4 4 ]
      @ additional_first_attributes
    else []
  in
  let all_attr = attribute :: other_attributes in
  let last_attributes = notes in
  let after_attributes =
    if is_first_measure then
      match tempo with
      | None -> []
      | Some x -> [create_metronome x]
    else []
  in
  let before_end = after_attributes @ last_attributes in
  (* XXX Guitar pro does not display five strings
     when adding the F clef, we put these lines in commentary for now
     let instrument_clef = instrument_clef_to_clef instrument.Music.clef in
     $create_clef instrument_clef 1$*)
  let measure_attr = ["number", Printf.sprintf "%d" measure_number] in
  <:xml<
   <measure $alist:measure_attr$>
     <attributes>
      $list:all_attr$
     </attributes>
     $list:before_end$
   </measure>
   >>

let create_string_measure ?(tempo=None) measure_number instrument notes =
  create_measure ~tempo measure_number notes
                 (create_string_note instrument)
                 (create_string_note ~chord:true instrument)
                 (create_clef `Tab 1)
                 [create_key 0 `Major;
                  create_instrument_staff_lines instrument;
                  create_transpose 0 0 0]

let create_drum_measure ?(tempo=None) measure_number notes id =
  create_measure ~tempo
                 measure_number notes
                 (create_drum_note id)
                 (create_drum_note ~chord:true id)
                 (drum_clef)
                 []

let create_voice_measure ?(tempo=None) measure_number notes id =
  create_measure ~tempo
                 measure_number notes
                 (create_voice_note id)
                 (create_voice_note ~chord:true id)
                 (create_clef `G 2)
                 [create_key 0 `Major]

type music_instrument = [
  | `String of (Music.string_instrument * Music.string_note Music.measures)
  | `Drum of Music.drum_note Music.measures
  | `Voice of Music.diatonic_note Music.measures ]

type instrument = {
    instrument_id: int;
    midi_instrument: Xml.t;
    instrument_and_measures: music_instrument;
}

let create_instrument id midi_instrument instrument_and_measures =
  {instrument_id = id;
   midi_instrument = midi_instrument id;
   instrument_and_measures = instrument_and_measures;
  }

module MidiInstruments = struct
    (* XXX cannot use "with xml" as:
       - the node have - in their name
       - ocaml does not allow - in the field of struct-s *)

    type midi_instrument = {
      channel: int;
      bank: int;
      program: int;
      volume: int;
      pan: int;
    }

    let create_midi_instrument_body t =
      <:xml<
      <midi-channel>$int:t.channel$</midi-channel>
      <midi-bank>$int:t.bank$</midi-bank>
      <midi-program>$int:t.program$</midi-program>
      <volume>$int:t.volume$</volume>
      <pan>$int:t.pan$</pan>
      >>

    let create_midi_instrument id name abbrev t =
      let attr = ["id", Printf.sprintf "%d" id] in
      <:xml<
      <score-part $alist:attr$>
        <part-name>$str:name$</part-name>
        <part-abbreviation>$str:abbrev$</part-abbreviation>
        <midi-instrument $alist:attr$>
          $create_midi_instrument_body t$
        </midi-instrument>
      </score-part>
      >>

    let bass_midi_instrument = {channel = 3;
                                bank = 1;
                                program = 34;
                                volume = 80;
                                pan = 0}

    let std5_bass id =
      create_midi_instrument id "Electric Bass" "E-Bass5" bass_midi_instrument

    let guitar_midi_instrument = {channel = 1;
                                  bank = 1;
                                  program = 30;
                                  volume = 40;
                                  pan = 0}

    let std_guitar id =
      create_midi_instrument id "Guitar" "E-Guitar" guitar_midi_instrument

    let voice_midi_instrument = {
        channel = 5;
        bank = 1;
        program = 54;
        volume = 80;
        pan = 0;
      }

    let std_voice id =
      create_midi_instrument id "Alto Voice" "Singer" voice_midi_instrument

    let std_drum = Drum_music_xml.create_midi_instrument

  end

let create title date tempo instruments =
  let attr = ["version", "2.0"] in
  let title = create_title title in
  let date = create_date date in
  let part_lists = List.map (fun x -> x.midi_instrument) instruments in
  let parts x =
    match x.instrument_and_measures with
    | `String (instrument, measures) -> List.map (fun (i, measure_notes) ->
                                                  let tempo =
                                                    if i == 0 then Some tempo
                                                    else None
                                                  in
                                                  create_string_measure ~tempo i instrument measure_notes)
                                                 (Music.enumerate measures)
    | `Drum measures -> List.map (fun (i, measure_notes) ->
                                  create_drum_measure i measure_notes x.instrument_id)
                                 (Music.enumerate measures)
    | `Voice measures -> List.map (fun (i, measure_notes) ->
                                   create_voice_measure i measure_notes x.instrument_id)
                                  (Music.enumerate measures)
  in

  let make_part x =
    let attr = ["id", Printf.sprintf "%d" x.instrument_id] in
    let inside_part = parts x in
    <:xml<
    <part $alist:attr$>
      $list:inside_part$
    </part>
  >>
  in
  let all_parts = List.map make_part instruments in
  let xml = <:xml<
    <score-partwise $alist:attr$>
      $title$
      $date$
      <part-list>
       $list:part_lists$
      </part-list>
      $list:all_parts$
    </score-partwise>
    >> in
  xml

let to_string xml_elt =
 decl ^ (Cow.Xml.to_string ~decl:false xml_elt)
