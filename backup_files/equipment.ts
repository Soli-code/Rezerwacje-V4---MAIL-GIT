import { RealtimeChannel } from '@supabase/supabase-js';
import { supabase } from './supabase';
import { sleep } from './utils';

export interface Equipment {
  id: string;
  name: string;
  description: string;
  price: number;
  deposit: number;
  image: string;
  categories: string[];
  quantity: number;
  promotional_price?: number;
  dimensions?: string;
  weight?: number;
  power_supply?: string;
  specifications?: Array<{
    id: string;
    key: string;
    value: string;
  }>;
  features?: Array<{
    id: string;
    text: string;
  }>;
  variants?: Array<{
    id: string;
    name: string;
    price: number;
  }>;
  technical_details?: Record<string, string>;
  created_at?: string;
  updated_at?: string;
  last_modified_by?: string;
}

let realtimeChannel: RealtimeChannel | null = null;

const MAX_RETRIES = 3;
const RETRY_DELAY = 1000; // 1 sekunda

export const getEquipment = async (retryCount = 0): Promise<Equipment[]> => {
  console.log('Wywołanie funkcji getEquipment');
  try {
    const { data, error } = await supabase
      .from('equipment')
      .select('*, specifications(*), features(*), variants(*)')
      .order('name');
    
    if (error) {
      console.error('Błąd pobierania sprzętu z Supabase:', error);
      throw error;
    }
    
    console.log('Pobrano sprzęt z Supabase:', data);
    return data || [];
  } catch (error) {
    console.error(`Próba ${retryCount + 1}/${MAX_RETRIES} nie powiodła się:`, error);
    
    if (retryCount < MAX_RETRIES) {
      await sleep(RETRY_DELAY * (retryCount + 1));
      return getEquipment(retryCount + 1);
    }
    
    throw new Error('Nie udało się pobrać danych po kilku próbach. Sprawdź połączenie z internetem.');
  }
};

export const addEquipment = async (equipment: Omit<Equipment, 'id'>) => {
  const { data: user } = await supabase.auth.getUser();
  
  const { data, error } = await supabase
    .from('equipment')
    .insert({
      ...equipment,
      last_modified_by: user.user?.id,
      updated_at: new Date().toISOString()
    })
    .select()
    .single();
    
  if (error) throw error;
  return data;
};

export const updateEquipment = async (id: string, equipment: Partial<Equipment>) => {
  const { data: user } = await supabase.auth.getUser();
  
  const { data, error } = await supabase
    .from('equipment')
    .update({
      ...equipment,
      last_modified_by: user.user?.id,
      updated_at: new Date().toISOString()
    })
    .eq('id', id)
    .select()
    .single();
    
  if (error) throw error;
  return data;
};

export const deleteEquipment = async (id: string) => {
  const { error } = await supabase
    .from('equipment')
    .delete()
    .eq('id', id);
    
  if (error) throw error;
};

export const subscribeToEquipmentUpdates = (onUpdate: (equipment: Equipment) => void) => {
  if (realtimeChannel) {
    realtimeChannel.unsubscribe();
  }

  realtimeChannel = supabase
    .channel('equipment_changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'equipment'
      },
      (payload) => {
        onUpdate(payload.new as Equipment);
      }
    )
    .subscribe();

  return () => {
    if (realtimeChannel) {
      realtimeChannel.unsubscribe();
      realtimeChannel = null;
    }
  };
};

const getEquipmentHistory = async (equipmentId: string) => {
  const { data, error } = await supabase
    .from('equipment_history')
    .select(`
      id,
      equipment_id,
      changed_at,
      changed_by,
      changes,
      profiles (
        id,
        email
      )
    `)
    .eq('equipment_id', equipmentId)
    .order('changed_at', { ascending: false });

  if (error) throw error;
  return data;
};

const getDraftEquipment = async (equipmentId: string) => {
  const { data, error } = await supabase
    .from('equipment_drafts')
    .select('*')
    .eq('equipment_id', equipmentId)
    .single();

  if (error && error.code !== 'PGRST116') throw error;
  return data;
};

const saveDraftEquipment = async (equipmentId: string, draftData: Partial<Equipment>) => {
  const { data: user } = await supabase.auth.getUser();
  
  const { data, error } = await supabase
    .from('equipment_drafts')
    .upsert({
      equipment_id: equipmentId,
      draft_data: draftData,
      last_modified_by: user.user?.id,
      updated_at: new Date().toISOString()
    })
    .select()
    .single();

  if (error) throw error;
  return data;
};

const deleteDraftEquipment = async (equipmentId: string) => {
  const { error } = await supabase
    .from('equipment_drafts')
    .delete()
    .eq('equipment_id', equipmentId);

  if (error) throw error;
};