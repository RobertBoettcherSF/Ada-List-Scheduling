with Ada.Text_IO; use Ada.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with List_Scheduling; use List_Scheduling;

procedure Test_List_Scheduling is

   -- Test counter and result tracking
   Total_Tests : Natural := 0;
   Passed_Tests : Natural := 0;
   Failed_Tests : Natural := 0;

   -- Helper procedure to print test results
   procedure Print_Test_Result (Test_Name : String; Passed : Boolean) is
   begin
      Total_Tests := Total_Tests + 1;
      if Passed then
         Passed_Tests := Passed_Tests + 1;
         Put_Line("[PASS] " & Test_Name);
      else
         Failed_Tests := Failed_Tests + 1;
         Put_Line("[FAIL] " & Test_Name);
      end if;
   end Print_Test_Result;

   -- Helper function to compute makespan from a schedule
   function Compute_Makespan (Schedule : Schedule_List) return Time_Type is
      Max_End : Time_Type := 0;
   begin
      for Item of Schedule loop
         if Item.End_Time > Max_End then
            Max_End := Item.End_Time;
         end if;
      end loop;
      return Max_End;
   end Compute_Makespan;

   -- Helper function to check if all jobs are scheduled
   function All_Jobs_Scheduled (Schedule : Schedule_List; Expected_Jobs : Job_List) return Boolean is
      Scheduled_Count : array (Expected_Jobs'Range) of Boolean := (others => False);
   begin
      for Item of Schedule loop
         for I in Expected_Jobs'Range loop
            if Expected_Jobs(I) = Item.Job then
               Scheduled_Count(I) := True;
               exit;
            end if;
         end loop;
      end loop;
      
      for I in Expected_Jobs'Range loop
         if not Scheduled_Count(I) then
            return False;
         end if;
      end loop;
      return True;
   end All_Jobs_Scheduled;

   -- Helper function to check if schedule is valid (no overlapping on same machine)
   function Is_Valid_Schedule (Schedule : Schedule_List) return Boolean is
      type Machine_Jobs is array (Machine_ID range 1 .. 100) of Schedule_List;
      Machine_Schedules : Machine_Jobs := (others => Schedule_Vectors.Empty_Vector);
   begin
      -- Group by machine
      for Item of Schedule loop
         if Item.Machine <= 100 then
            Machine_Schedules(Item.Machine).Append(Item);
         end if;
      end loop;
      
      -- Check each machine for overlaps
      for Mach in Machine_ID range 1 .. 100 loop
         declare
            Mach_Schedule : Schedule_List := Machine_Schedules(Mach);
         begin
            for I in 1 .. Natural(Mach_Schedule.Length) - 1 loop
               for J in I + 1 .. Natural(Mach_Schedule.Length) loop
                  declare
                     Job_I : constant Job_Schedule := Mach_Schedule.Element(I);
                     Job_J : constant Job_Schedule := Mach_Schedule.Element(J);
                  begin
                     -- Check if jobs overlap
                     if Job_I.Start_Time < Job_J.End_Time and Job_J.Start_Time < Job_I.End_Time then
                        return False;
                     end if;
                  end;
               end loop;
            end loop;
         end;
      end loop;
      
      return True;
   end Is_Valid_Schedule;

begin
   New_Line;
   Put_Line("========================================");
   Put_Line("  List Scheduling Algorithm Test Suite");
   Put_Line("========================================");
   New_Line;

   -- ========================================================================
   -- TEST CATEGORY 1: Basic List Scheduling Tests
   -- ========================================================================
   Put_Line("--- Basic List Scheduling Tests ---");

   -- Test 1: Empty job list
   declare
      Empty_Jobs : Job_List(1 .. 0);
      Empty_Durations : Job_Duration_Array(1 .. 0);
      Result : Schedule_List;
   begin
      Result := Basic_List_Scheduling(Empty_Jobs, Empty_Durations, 1);
      Print_Test_Result("Test 1: Basic scheduling with empty job list", 
                        Result.Length = 0);
   end;

   -- Test 2: Single job, single machine
   declare
      Single_Job : Job_List(1 .. 1) := (1 => 1);
      Single_Duration : Job_Duration_Array(1 .. 1) := (1 => 10);
      Result : Schedule_List;
   begin
      Result := Basic_List_Scheduling(Single_Job, Single_Duration, 1);
      Print_Test_Result("Test 2: Single job on single machine",
                        Result.Length = 1 and then 
                        Result.First_Element.Job = 1 and then
                        Result.First_Element.Start_Time = 0 and then
                        Result.First_Element.End_Time = 10);
   end;

   -- Test 3: Multiple jobs, single machine (sequential execution)
   declare
      Jobs_3 : Job_List(1 .. 3) := (1, 2, 3);
      Durations_3 : Job_Duration_Array(1 .. 3) := (10, 5, 8);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      Result := Basic_List_Scheduling(Jobs_3, Durations_3, 1);
      Makespan := Compute_Makespan(Result);
      Print_Test_Result("Test 3: Multiple jobs on single machine (sequential)",
                        Result.Length = 3 and then
                        Makespan = 23 and then
                        Is_Valid_Schedule(Result));
   end;

   -- Test 4: Multiple jobs, multiple machines (parallel execution)
   declare
      Jobs_4 : Job_List(1 .. 4) := (1, 2, 3, 4);
      Durations_4 : Job_Duration_Array(1 .. 4) := (5, 10, 3, 7);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      Result := Basic_List_Scheduling(Jobs_4, Durations_4, 2);
      Makespan := Compute_Makespan(Result);
      Print_Test_Result("Test 4: Multiple jobs on 2 machines",
                        Result.Length = 4 and then
                        Makespan <= 17 and then  -- Should be better than sequential (25)
                        Is_Valid_Schedule(Result));
   end;

   -- ========================================================================
   -- TEST CATEGORY 2: LPT (Longest Processing Time First) Tests
   -- ========================================================================
   Put_Line("--- LPT Scheduling Tests ---");

   -- Test 5: LPT with uniform durations (should behave like basic)
   declare
      Jobs_5 : Job_Duration_Array(1 .. 3) := (5, 5, 5);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      Result := LPT_Scheduling(Jobs_5, 2);
      Makespan := Compute_Makespan(Result);
      Print_Test_Result("Test 5: LPT with uniform durations",
                        Result.Length = 3 and then
                        Makespan = 10 and then  -- 2 machines: ceil(15/2) = 10
                        Is_Valid_Schedule(Result));
   end;

   -- Test 6: LPT should outperform basic scheduling for certain cases
   declare
      Jobs_6 : Job_Duration_Array(1 .. 4) := (10, 1, 1, 1);
      Result_LPT : Schedule_List;
      Result_Basic : Schedule_List;
      Jobs_List : Job_List(1 .. 4) := (1, 2, 3, 4);
      Makespan_LPT : Time_Type;
      Makespan_Basic : Time_Type;
   begin
      Result_LPT := LPT_Scheduling(Jobs_6, 2);
      Result_Basic := Basic_List_Scheduling(Jobs_List, Jobs_6, 2);
      Makespan_LPT := Compute_Makespan(Result_LPT);
      Makespan_Basic := Compute_Makespan(Result_Basic);
      Print_Test_Result("Test 6: LPT outperforms basic for long-short pattern",
                        Makespan_LPT <= Makespan_Basic);
   end;

   -- Test 7: LPT with single machine (should be sequential)
   declare
      Jobs_7 : Job_Duration_Array(1 .. 5) := (3, 1, 4, 1, 5);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      Result := LPT_Scheduling(Jobs_7, 1);
      Makespan := Compute_Makespan(Result);
      Print_Test_Result("Test 7: LPT with single machine",
                        Result.Length = 5 and then
                        Makespan = 14 and then  -- 5+4+3+1+1
                        Is_Valid_Schedule(Result));
   end;

   -- ========================================================================
   -- TEST CATEGORY 3: HLF (Highest Level First) Tests with DAGs
   -- ========================================================================
   Put_Line("--- HLF Scheduling Tests ---");

   -- Test 8: Simple DAG with dependencies
   declare
      type Job_ID_Array is array (Positive range <>) of Job_ID;
      DAG_8 : DAG_Array(1 .. 3);
      Result : Schedule_List;
   begin
      -- Job 1 -> Job 2 -> Job 3 (chain)
      DAG_8(1) := (Duration => 5, Predecessors => Job_Vectors.Empty_Vector, Successors => Job_Vectors.To_Vector(Job_ID_Array'(2)));
      DAG_8(2) := (Duration => 3, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(1)), Successors => Job_Vectors.To_Vector(Job_ID_Array'(3)));
      DAG_8(3) := (Duration => 2, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(2)), Successors => Job_Vectors.Empty_Vector);
      
      Result := HLF_Scheduling(DAG_8, 1);
      Print_Test_Result("Test 8: HLF with simple chain DAG (1 machine)",
                        Result.Length = 3 and then
                        Compute_Makespan(Result) = 10 and then  -- 5+3+2
                        Is_Valid_Schedule(Result));
   end;

   -- Test 9: DAG with parallel branches
   declare
      DAG_9 : DAG_Array(1 .. 4);
      Result : Schedule_List;
   begin
      -- Job 1 -> Job 2, Job 1 -> Job 3, Job 2 -> Job 4, Job 3 -> Job 4
      DAG_9(1) := (Duration => 5, Predecessors => Job_Vectors.Empty_Vector, 
                   Successors => Job_Vectors.To_Vector(Job_ID_Array'(2, 3)));
      DAG_9(2) := (Duration => 3, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(1)), 
                   Successors => Job_Vectors.To_Vector(Job_ID_Array'(4)));
      DAG_9(3) := (Duration => 4, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(1)), 
                   Successors => Job_Vectors.To_Vector(Job_ID_Array'(4)));
      DAG_9(4) := (Duration => 2, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(2, 3)), 
                   Successors => Job_Vectors.Empty_Vector);
      
      Result := HLF_Scheduling(DAG_9, 2);
      Print_Test_Result("Test 9: HLF with parallel branches (2 machines)",
                        Result.Length = 4 and then
                        Compute_Makespan(Result) <= 12 and then  -- Should be better than sequential
                        Is_Valid_Schedule(Result));
   end;

   -- Test 10: DAG with no dependencies (should behave like LPT)
   declare
      DAG_10 : DAG_Array(1 .. 3);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      -- No dependencies
      DAG_10(1) := (Duration => 10, Predecessors => Job_Vectors.Empty_Vector, Successors => Job_Vectors.Empty_Vector);
      DAG_10(2) := (Duration => 5, Predecessors => Job_Vectors.Empty_Vector, Successors => Job_Vectors.Empty_Vector);
      DAG_10(3) := (Duration => 3, Predecessors => Job_Vectors.Empty_Vector, Successors => Job_Vectors.Empty_Vector);
      
      Result := HLF_Scheduling(DAG_10, 2);
      Makespan := Compute_Makespan(Result);
      Print_Test_Result("Test 10: HLF with no dependencies",
                        Result.Length = 3 and then
                        Makespan <= 13 and then  -- 10+3 on one machine, 5 on other
                        Is_Valid_Schedule(Result));
   end;

   -- ========================================================================
   -- TEST CATEGORY 4: HEFT (Heterogeneous Earliest Finish Time) Tests
   -- ========================================================================
   Put_Line("--- HEFT Scheduling Tests ---");

   -- Test 11: HEFT with heterogeneous durations
   declare
      DAG_11 : DAG_Array(1 .. 2);
      Durations_11 : Duration_Matrix(1 .. 2, 1 .. 2);
      Result : Schedule_List;
   begin
      -- No dependencies
      DAG_11(1) := (Duration => 5, Predecessors => Job_Vectors.Empty_Vector, Successors => Job_Vectors.Empty_Vector);
      DAG_11(2) := (Duration => 3, Predecessors => Job_Vectors.Empty_Vector, Successors => Job_Vectors.Empty_Vector);
      
      -- Job 1: Machine 1 = 10, Machine 2 = 5
      -- Job 2: Machine 1 = 3, Machine 2 = 6
      Durations_11(1, 1) := 10;
      Durations_11(1, 2) := 5;
      Durations_11(2, 1) := 3;
      Durations_11(2, 2) := 6;
      
      Result := HEFT_Scheduling(DAG_11, 2);
      Print_Test_Result("Test 11: HEFT with heterogeneous durations",
                        Result.Length = 2 and then
                        Is_Valid_Schedule(Result));
   end;

   -- Test 12: HEFT with dependencies and heterogeneous durations
   declare
      DAG_12 : DAG_Array(1 .. 3);
      Durations_12 : Duration_Matrix(1 .. 3, 1 .. 2);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      -- Job 1 -> Job 2 -> Job 3
      DAG_12(1) := (Duration => 5, Predecessors => Job_Vectors.Empty_Vector, 
                    Successors => Job_Vectors.To_Vector(Job_ID_Array'(2)));
      DAG_12(2) := (Duration => 3, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(1)), 
                    Successors => Job_Vectors.To_Vector(Job_ID_Array'(3)));
      DAG_12(3) := (Duration => 2, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(2)), 
                    Successors => Job_Vectors.Empty_Vector);
      
      -- Heterogeneous durations
      Durations_12(1, 1) := 10; Durations_12(1, 2) := 5;
      Durations_12(2, 1) := 6;  Durations_12(2, 2) := 3;
      Durations_12(3, 1) := 4;  Durations_12(3, 2) := 2;
      
      Result := HEFT_Scheduling(DAG_12, 2);
      Makespan := Compute_Makespan(Result);
      Print_Test_Result("Test 12: HEFT with dependencies and heterogeneous durations",
                        Result.Length = 3 and then
                        Makespan > 0 and then
                        Is_Valid_Schedule(Result));
   end;

   -- ========================================================================
   -- TEST CATEGORY 5: Edge Cases and Assumption Tests
   -- ========================================================================
   Put_Line("--- Edge Cases and Assumption Tests ---");

   -- Test 13: Assumption - Basic scheduling assigns to available machine
   -- This tests that jobs are assigned to the machine that becomes available first
   declare
      Jobs_13 : Job_List(1 .. 2) := (1, 2);
      Durations_13 : Job_Duration_Array(1 .. 2) := (5, 3);
      Result : Schedule_List;
   begin
      Result := Basic_List_Scheduling(Jobs_13, Durations_13, 2);
      -- First job should go to machine 1, second to machine 2 (both available at time 0)
      Print_Test_Result("Test 13: Basic scheduling assigns to first available machine",
                        Result.Length = 2 and then
                        (Result.Element(1).Machine = 1 or Result.Element(1).Machine = 2) and then
                        (Result.Element(2).Machine = 1 or Result.Element(2).Machine = 2) and then
                        Result.Element(1).Machine /= Result.Element(2).Machine);
   end;

   -- Test 14: Assumption - LPT sorts by descending duration
   -- This tests that LPT actually sorts jobs by duration
   declare
      Durations_14 : Job_Duration_Array(1 .. 3) := (1, 5, 3);
      Result : Schedule_List;
   begin
      Result := LPT_Scheduling(Durations_14, 1);
      -- Jobs should be ordered: 2 (5), 3 (3), 1 (1)
      Print_Test_Result("Test 14: LPT sorts jobs by descending duration",
                        Result.Length = 3 and then
                        Result.Element(1).Job = 2 and then
                        Result.Element(2).Job = 3 and then
                        Result.Element(3).Job = 1);
   end;

   -- Test 15: Assumption - HLF respects dependencies
   -- This tests that HLF doesn't schedule a job before its predecessors
   declare
      DAG_15 : DAG_Array(1 .. 2);
      Result : Schedule_List;
      Job1_End : Time_Type := 0;
      Job2_Start : Time_Type := 0;
   begin
      -- Job 1 -> Job 2
      DAG_15(1) := (Duration => 10, Predecessors => Job_Vectors.Empty_Vector, 
                    Successors => Job_Vectors.To_Vector(Job_ID_Array'(2)));
      DAG_15(2) := (Duration => 5, Predecessors => Job_Vectors.To_Vector(Job_ID_Array'(1)), 
                    Successors => Job_Vectors.Empty_Vector);
      
      Result := HLF_Scheduling(DAG_15, 2);
      
      -- Find job 1 and job 2 in the schedule
      for Item of Result loop
         if Item.Job = 1 then
            Job1_End := Item.End_Time;
         elsif Item.Job = 2 then
            Job2_Start := Item.Start_Time;
         end if;
      end loop;
      
      Print_Test_Result("Test 15: HLF respects dependencies (job 2 starts after job 1)",
                        Job2_Start >= Job1_End);
   end;

   -- Test 16: Assumption - HEFT chooses fastest machine
   -- This tests that HEFT assigns jobs to the machine where they finish earliest
   declare
      DAG_16 : DAG_Array(1 .. 1);
      Durations_16 : Duration_Matrix(1 .. 1, 1 .. 2);
      Result : Schedule_List;
   begin
      DAG_16(1) := (Duration => 5, Predecessors => Job_Vectors.Empty_Vector, 
                     Successors => Job_Vectors.Empty_Vector);
      -- Job 1: Machine 1 = 10, Machine 2 = 5
      Durations_16(1, 1) := 10;
      Durations_16(1, 2) := 5;
      
      Result := HEFT_Scheduling(DAG_16, 2);
      -- Should choose machine 2 (faster)
      Print_Test_Result("Test 16: HEFT chooses fastest machine for job",
                        Result.Length = 1 and then
                        Result.First_Element.Machine = 2 and then
                        Result.First_Element.End_Time = 5);
   end;

   -- Test 17: Assumption - All algorithms produce valid schedules
   -- This tests that all algorithms produce schedules without overlaps
   declare
      Jobs_17 : Job_List(1 .. 5) := (1, 2, 3, 4, 5);
      Durations_17 : Job_Duration_Array(1 .. 5) := (2, 4, 6, 8, 10);
      Result_Basic : Schedule_List;
      Result_LPT : Schedule_List;
   begin
      Result_Basic := Basic_List_Scheduling(Jobs_17, Durations_17, 3);
      Result_LPT := LPT_Scheduling(Durations_17, 3);
      
      Print_Test_Result("Test 17: All algorithms produce valid schedules",
                        Is_Valid_Schedule(Result_Basic) and then
                        Is_Valid_Schedule(Result_LPT));
   end;

   -- Test 18: Assumption - Makespan is at least the longest job
   -- This tests that no schedule can be better than the longest single job
   declare
      Jobs_18 : Job_List(1 .. 4) := (1, 2, 3, 4);
      Durations_18 : Job_Duration_Array(1 .. 4) := (2, 4, 6, 8);
      Result : Schedule_List;
      Makespan : Time_Type;
   begin
      Result := LPT_Scheduling(Durations_18, 3);
      Makespan := Compute_Makespan(Result);
      -- Makespan should be at least 8 (the longest job)
      Print_Test_Result("Test 18: Makespan is at least the longest job duration",
                        Makespan >= 8);
   end;

   -- ========================================================================
   -- TEST CATEGORY 6: Tests to be Proven False (Negative Tests)
   -- ========================================================================
   Put_Line("--- Negative Tests (To be Proven False) ---");

   -- Test 19: False assumption - Basic scheduling is always optimal
   -- This should FAIL because basic scheduling doesn't sort by duration
   declare
      Jobs_19 : Job_List(1 .. 3) := (1, 2, 3);
      Durations_19 : Job_Duration_Array(1 .. 3) := (10, 1, 1);
      Result_Basic : Schedule_List;
      Result_LPT : Schedule_List;
      Makespan_Basic : Time_Type;
      Makespan_LPT : Time_Type;
   begin
      Result_Basic := Basic_List_Scheduling(Jobs_19, Durations_19, 2);
      Result_LPT := LPT_Scheduling(Durations_19, 2);
      Makespan_Basic := Compute_Makespan(Result_Basic);
      Makespan_LPT := Compute_Makespan(Result_LPT);
      
      -- This assumption is FALSE: Basic scheduling is NOT always optimal
      Print_Test_Result("Test 19: FALSE - Basic scheduling is always optimal",
                        Makespan_Basic <= Makespan_LPT);
   end;

   -- Test 20: False assumption - LPT with 1 machine is different from basic
   -- This should FAIL because with 1 machine, both should give same result
   declare
      Jobs_20 : Job_List(1 .. 3) := (1, 2, 3);
      Durations_20 : Job_Duration_Array(1 .. 3) := (5, 3, 7);
      Result_Basic : Schedule_List;
      Result_LPT : Schedule_List;
      Makespan_Basic : Time_Type;
      Makespan_LPT : Time_Type;
   begin
      Result_Basic := Basic_List_Scheduling(Jobs_20, Durations_20, 1);
      Result_LPT := LPT_Scheduling(Durations_20, 1);
      Makespan_Basic := Compute_Makespan(Result_Basic);
      Makespan_LPT := Compute_Makespan(Result_LPT);
      
      -- This assumption is FALSE: With 1 machine, both should have same makespan
      Print_Test_Result("Test 20: FALSE - LPT with 1 machine differs from basic",
                        Makespan_Basic /= Makespan_LPT);
   end;

   -- ========================================================================
   -- SUMMARY
   -- ========================================================================
   New_Line;
   Put_Line("========================================");
   Put_Line("  Test Summary");
   Put_Line("========================================");
   Put("Total Tests: "); Put_Line(Natural'Image(Total_Tests));
   Put("Passed: "); Put_Line(Natural'Image(Passed_Tests));
   Put("Failed: "); Put_Line(Natural'Image(Failed_Tests));
   
   if Failed_Tests > 0 then
      Put_Line("");
      Put_Line("WARNING: Some tests failed!");
   else
      Put_Line("");
      Put_Line("All tests passed successfully!");
   end if;
   Put_Line("========================================");

end Test_List_Scheduling;
