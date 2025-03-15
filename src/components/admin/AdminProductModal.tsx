import React, { useState, useRef, useEffect } from 'react';
import { X, Plus, Trash2, Save, Image as ImageIcon, Loader2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useEditor, EditorContent } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import imageCompression from 'browser-image-compression';
import { DragDropContext, Droppable, Draggable } from '@hello-pangea/dnd';
import { supabase } from '../../lib/supabase';

interface Specification {
  id: string;
  key: string;
  value: string;
}

interface Feature {
  id: string;
  text: string;
}

interface Variant {
  id: string;
  name: string;
  price: number;
}

interface Product {
  id?: string;
  name: string;
  description: string;
  price: number;
  deposit: number;
  image: string;
  categories: string[];
  quantity: number;
  specifications: Specification[];
  features: Feature[];
  variants: Variant[];
  technical_details?: Record<string, string>;
}

interface AdminProductModalProps {
  product: Product | null;
  isOpen: boolean;
  onClose: () => void;
  onSave: (product: Product) => Promise<void>;
}

const AdminProductModal: React.FC<AdminProductModalProps> = ({
  product,
  isOpen,
  onClose,
  onSave
}) => {
  const [formData, setFormData] = useState<Product>({
    name: '',
    description: '',
    price: 0,
    deposit: 0,
    image: '',
    categories: ['budowlany'],
    quantity: 1,
    specifications: [],
    features: [],
    variants: [],
    technical_details: {}
  });
  const [isDragging, setIsDragging] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});
  const fileInputRef = useRef<HTMLInputElement>(null);
  const modalRef = useRef<HTMLDivElement>(null);
  
  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({
        placeholder: 'Wprowadź opis produktu...'
      })
    ],
    content: formData.description,
    onUpdate: ({ editor }) => {
      setFormData(prev => ({
        ...prev,
        description: editor.getHTML()
      }));
    }
  });

  useEffect(() => {
    if (product) {
      setFormData({
        ...product,
        specifications: product.specifications || [],
        features: product.features || [],
        variants: product.variants || [],
        technical_details: product.technical_details || {}
      });
      setImagePreview(product.image);
    }
  }, [product]);

  const handleImageDrop = async (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    setIsDragging(false);

    const file = e.dataTransfer.files[0];
    if (file) {
      await handleImageUpload(file);
    }
  };

  const handleImageUpload = async (file: File) => {
    try {
      const options = {
        maxSizeMB: 1,
        maxWidthOrHeight: 1920,
        useWebWorker: true
      };

      const compressedFile = await imageCompression(file, options);
      const reader = new FileReader();
      
      reader.onloadend = () => {
        setImagePreview(reader.result as string);
        setFormData(prev => ({ ...prev, image: reader.result as string }));
      };

      reader.readAsDataURL(compressedFile);
    } catch (error) {
      console.error('Error compressing image:', error);
    }
  };

  const handleSpecificationChange = (id: string, field: 'key' | 'value', value: string) => {
    setFormData(prev => ({
      ...prev,
      specifications: prev.specifications.map(spec =>
        spec.id === id ? { ...spec, [field]: value } : spec
      )
    }));
  };

  const addSpecification = () => {
    setFormData(prev => ({
      ...prev,
      specifications: [
        ...prev.specifications,
        { id: crypto.randomUUID(), key: '', value: '' }
      ]
    }));
  };

  const removeSpecification = (id: string) => {
    setFormData(prev => ({
      ...prev,
      specifications: prev.specifications.filter(spec => spec.id !== id)
    }));
  };

  const handleFeatureChange = (id: string, text: string) => {
    setFormData(prev => ({
      ...prev,
      features: prev.features.map(feature =>
        feature.id === id ? { ...feature, text } : feature
      )
    }));
  };

  const addFeature = () => {
    setFormData(prev => ({
      ...prev,
      features: [
        ...prev.features,
        { id: crypto.randomUUID(), text: '' }
      ]
    }));
  };

  const removeFeature = (id: string) => {
    setFormData(prev => ({
      ...prev,
      features: prev.features.filter(feature => feature.id !== id)
    }));
  };

  const handleVariantChange = (id: string, field: 'name' | 'price', value: string | number) => {
    setFormData(prev => ({
      ...prev,
      variants: prev.variants.map(variant =>
        variant.id === id ? { ...variant, [field]: value } : variant
      )
    }));
  };

  const addVariant = () => {
    setFormData(prev => ({
      ...prev,
      variants: [
        ...prev.variants,
        { id: crypto.randomUUID(), name: '', price: 0 }
      ]
    }));
  };

  const removeVariant = (id: string) => {
    setFormData(prev => ({
      ...prev,
      variants: prev.variants.filter(variant => variant.id !== id)
    }));
  };

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};

    if (!formData.name.trim()) {
      errors.name = 'Nazwa produktu jest wymagana';
    }
    if (!formData.description.trim()) {
      errors.description = 'Opis produktu jest wymagany';
    }
    if (formData.price <= 0) {
      errors.price = 'Cena musi być większa od 0';
    }
    if (formData.quantity < 0) {
      errors.quantity = 'Ilość nie może być ujemna';
    }
    if (!formData.image) {
      errors.image = 'Zdjęcie produktu jest wymagane';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateForm()) {
      return;
    }

    setIsSaving(true);
    try {
      await onSave(formData);
      onClose();
    } catch (error) {
      console.error('Error saving product:', error);
    } finally {
      setIsSaving(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black bg-opacity-50">
      <div className="min-h-screen px-4 text-center">
        <div className="inline-block w-full max-w-6xl my-8 text-left align-middle">
          <motion.div
            ref={modalRef}
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="bg-white rounded-lg shadow-xl overflow-hidden"
          >
            <form onSubmit={handleSubmit}>
              {/* Header */}
              <div className="px-6 py-4 border-b flex items-center justify-between">
                <h2 className="text-2xl font-semibold text-gray-900">
                  {product ? 'Edytuj produkt' : 'Dodaj nowy produkt'}
                </h2>
                <button
                  type="button"
                  onClick={onClose}
                  className="p-2 hover:bg-gray-100 rounded-full"
                >
                  <X className="w-6 h-6" />
                </button>
              </div>

              {/* Content */}
              <div className="px-6 py-4 max-h-[calc(100vh-200px)] overflow-y-auto">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {/* Left Column */}
                  <div>
                    {/* Basic Information */}
                    <div className="space-y-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Nazwa produktu
                        </label>
                        <input
                          type="text"
                          value={formData.name}
                          onChange={e => setFormData(prev => ({ ...prev, name: e.target.value }))}
                          className={`mt-1 block w-full rounded-md border ${
                            validationErrors.name ? 'border-red-500' : 'border-gray-300'
                          } px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500`}
                        />
                        {validationErrors.name && (
                          <p className="mt-1 text-sm text-red-500">{validationErrors.name}</p>
                        )}
                      </div>

                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Kategoria
                        </label>
                        <select
                          value={formData.categories[0]}
                          onChange={e => setFormData(prev => ({ ...prev, categories: [e.target.value] }))}
                          className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                        >
                          <option value="budowlany">Sprzęt budowlany</option>
                          <option value="ogrodniczy">Sprzęt ogrodniczy</option>
                        </select>
                      </div>

                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700">
                            Cena (zł/dzień)
                          </label>
                          <input
                            type="number"
                            min="0"
                            step="0.01"
                            value={formData.price}
                            onChange={e => setFormData(prev => ({ ...prev, price: parseFloat(e.target.value) }))}
                            className={`mt-1 block w-full rounded-md border ${
                              validationErrors.price ? 'border-red-500' : 'border-gray-300'
                            } px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500`}
                          />
                          {validationErrors.price && (
                            <p className="mt-1 text-sm text-red-500">{validationErrors.price}</p>
                          )}
                        </div>

                        <div>
                          <label className="block text-sm font-medium text-gray-700">
                            Kaucja (zł)
                          </label>
                          <input
                            type="number"
                            min="0"
                            step="0.01"
                            value={formData.deposit}
                            onChange={e => setFormData(prev => ({ ...prev, deposit: parseFloat(e.target.value) }))}
                            className="mt-1 block w-full rounded-md border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                          />
                        </div>
                      </div>

                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Dostępna ilość
                        </label>
                        <input
                          type="number"
                          min="0"
                          value={formData.quantity}
                          onChange={e => setFormData(prev => ({ ...prev, quantity: parseInt(e.target.value) }))}
                          className={`mt-1 block w-full rounded-md border ${
                            validationErrors.quantity ? 'border-red-500' : 'border-gray-300'
                          } px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500`}
                        />
                        {validationErrors.quantity && (
                          <p className="mt-1 text-sm text-red-500">{validationErrors.quantity}</p>
                        )}
                      </div>
                    </div>

                    {/* Image Upload */}
                    <div className="mt-6">
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Zdjęcie produktu
                      </label>
                      <div
                        className={`border-2 border-dashed rounded-lg p-4 text-center ${
                          isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300'
                        } ${validationErrors.image ? 'border-red-500' : ''}`}
                        onDragOver={e => {
                          e.preventDefault();
                          setIsDragging(true);
                        }}
                        onDragLeave={() => setIsDragging(false)}
                        onDrop={handleImageDrop}
                      >
                        {imagePreview ? (
                          <div className="relative">
                            <img
                              src={imagePreview}
                              alt="Preview"
                              className="max-h-48 mx-auto object-contain"
                            />
                            <button
                              type="button"
                              onClick={() => {
                                setImagePreview(null);
                                setFormData(prev => ({ ...prev, image: '' }));
                              }}
                              className="absolute top-2 right-2 p-1 bg-red-500 text-white rounded-full hover:bg-red-600"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        ) : (
                          <div
                            className="cursor-pointer"
                            onClick={() => fileInputRef.current?.click()}
                          >
                            <ImageIcon className="w-12 h-12 mx-auto text-gray-400" />
                            <p className="mt-2 text-sm text-gray-500">
                              Przeciągnij i upuść zdjęcie lub kliknij, aby wybrać
                            </p>
                          </div>
                        )}
                        <input
                          ref={fileInputRef}
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={e => {
                            const file = e.target.files?.[0];
                            if (file) {
                              handleImageUpload(file);
                            }
                          }}
                        />
                      </div>
                      {validationErrors.image && (
                        <p className="mt-1 text-sm text-red-500">{validationErrors.image}</p>
                      )}
                    </div>
                  </div>

                  {/* Right Column */}
                  <div className="space-y-6">
                    {/* Description */}
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Opis produktu
                      </label>
                      <EditorContent 
                        editor={editor} 
                        className={`prose max-w-none border rounded-lg p-4 min-h-[200px] ${
                          validationErrors.description ? 'border-red-500' : 'border-gray-300'
                        }`}
                      />
                      {validationErrors.description && (
                        <p className="mt-1 text-sm text-red-500">{validationErrors.description}</p>
                      )}
                    </div>

                    {/* Specifications */}
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <label className="block text-sm font-medium text-gray-700">
                          Specyfikacja techniczna
                        </label>
                        <button
                          type="button"
                          onClick={addSpecification}
                          className="text-blue-600 hover:text-blue-700 text-sm flex items-center"
                        >
                          <Plus className="w-4 h-4 mr-1" />
                          Dodaj parametr
                        </button>
                      </div>
                      <DragDropContext
                        onDragEnd={result => {
                          if (!result.destination) return;
                          const specs = Array.from(formData.specifications);
                          const [removed] = specs.splice(result.source.index, 1);
                          specs.splice(result.destination.index, 0, removed);
                          setFormData(prev => ({ ...prev, specifications: specs }));
                        }}
                      >
                        <Droppable droppableId="specifications">
                          {provided => (
                            <div
                              ref={provided.innerRef}
                              {...provided.droppableProps}
                              className="space-y-2"
                            >
                              {formData.specifications.map((spec, index) => (
                                <Draggable
                                  key={spec.id}
                                  draggableId={spec.id}
                                  index={index}
                                >
                                  {provided => (
                                    <div
                                      ref={provided.innerRef}
                                      {...provided.draggableProps}
                                      {...provided.dragHandleProps}
                                      className="flex gap-2"
                                    >
                                      <input
                                        type="text"
                                        value={spec.key}
                                        onChange={e => handleSpecificationChange(spec.id, 'key', e.target.value)}
                                        placeholder="Parametr"
                                        className="flex-1 rounded-md border border-gray-300 px-3 py-2"
                                      />
                                      <input
                                        type="text"
                                        value={spec.value}
                                        onChange={e => handleSpecificationChange(spec.id, 'value', e.target.value)}
                                        placeholder="Wartość"
                                        className="flex-1 rounded-md border border-gray-300 px-3 py-2"
                                      />
                                      <button
                                        type="button"
                                        onClick={() => removeSpecification(spec.id)}
                                        className="p-2 text-red-500 hover:bg-red-50 rounded"
                                      >
                                        <Trash2 className="w-5 h-5" />
                                      </button>
                                    </div>
                                  )}
                                </Draggable>
                              ))}
                              {provided.placeholder}
                            </div>
                          )}
                        </Droppable>
                      </DragDropContext>
                    </div>

                    {/* Features */}
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <label className="block text-sm font-medium text-gray-700">
                          Główne cechy
                        </label>
                        <button
                          type="button"
                          onClick={addFeature}
                          className="text-blue-600 hover:text-blue-700 text-sm flex items-center"
                        >
                          <Plus className="w-4 h-4 mr-1" />
                          Dodaj cechę
                        </button>
                      </div>
                      <DragDropContext
                        onDragEnd={result => {
                          if (!result.destination) return;
                          const features = Array.from(formData.features);
                          const [removed] = features.splice(result.source.index, 1);
                          features.splice(result.destination.index, 0, removed);
                          setFormData(prev => ({ ...prev, features }));
                        }}
                      >
                        <Droppable droppableId="features">
                          {provided => (
                            <div
                              ref={provided.innerRef}
                              {...provided.droppableProps}
                              className="space-y-2"
                            >
                              {formData.features.map((feature, index) => (
                                <Draggable
                                  key={feature.id}
                                  draggableId={feature.id}
                                  index={index}
                                >
                                  {provided => (
                                    <div
                                      ref={provided.innerRef}
                                      {...provided.draggableProps}
                                      {...provided.dragHandleProps}
                                      className="flex gap-2"
                                    >
                                      <input
                                        type="text"
                                        value={feature.text}
                                        onChange={e => handleFeatureChange(feature.id, e.target.value)}
                                        placeholder="Cecha produktu"
                                        className="flex-1 rounded-md border border-gray-300 px-3 py-2"
                                      />
                                      <button
                                        type="button"
                                        onClick={() => removeFeature(feature.id)}
                                        className="p-2 text-red-500 hover:bg-red-50 rounded"
                                      >
                                        <Trash2 className="w-5 h-5" />
                                      </button>
                                    </div>
                                  )}
                                </Draggable>
                              ))}
                              {provided.placeholder}
                            </div>
                          )}
                        </Droppable>
                      </DragDropContext>
                    </div>

                    {/* Variants */}
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <label className="block text-sm font-medium text-gray-700">
                          Warianty produktu
                        </label>
                        <button
                          type="button"
                          onClick={addVariant}
                          className="text-blue-600 hover:text-blue-700 text-sm flex items-center"
                        >
                          <Plus className="w-4 h-4 mr-1" />
                          Dodaj wariant
                        </button>
                      </div>
                      <DragDropContext
                        onDragEnd={result => {
                          if (!result.destination) return;
                          const variants = Array.from(formData.variants);
                          const [removed] = variants.splice(result.source.index, 1);
                          variants.splice(result.destination.index, 0, removed);
                          setFormData(prev => ({ ...prev, variants }));
                        }}
                      >
                        <Droppable droppableId="variants">
                          {provided => (
                            <div
                              ref={provided.innerRef}
                              {...provided.droppableProps}
                              className="space-y-2"
                            >
                              {formData.variants.map((variant, index) => (
                                <Draggable
                                  key={variant.id}
                                  draggableId={variant.id}
                                  index={index}
                                >
                                  {provided => (
                                    <div
                                      ref={provided.innerRef}
                                      {...provided.draggableProps}
                                      {...provided.dragHandleProps}
                                      className="flex gap-2"
                                    >
                                      <input
                                        type="text"
                                        value={variant.name}
                                        onChange={e => handleVariantChange(variant.id, 'name', e.target.value)}
                                        placeholder="Nazwa wariantu"
                                        className="flex-1 rounded-md border border-gray-300 px-3 py-2"
                                      />
                                      <input
                                        type="number"
                                        min="0"
                                        step="0.01"
                                        value={variant.price}
                                        onChange={e => handleVariantChange(variant.id, 'price', parseFloat(e.target.value))}
                                        placeholder="Cena"
                                        className="w-32 rounded-md border border-gray-300 px-3 py-2"
                                      />
                                      <button
                                        type="button"
                                        onClick={() => removeVariant(variant.id)}
                                        className="p-2 text-red-500 hover:bg-red-50 rounded"
                                      >
                                        <Trash2 className="w-5 h-5" />
                                      </button>
                                    </div>
                                  )}
                                </Draggable>
                              ))}
                              {provided.placeholder}
                            </div>
                          )}
                        </Droppable>
                      </DragDropContext>
                    </div>
                  </div>
                </div>
              </div>

              {/* Footer */}
              <div className="px-6 py-4 border-t bg-gray-50 flex justify-end space-x-4">
                <button
                  type="button"
                  onClick={onClose}
                  className="px-4 py-2 text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Anuluj
                </button>
                <button
                  type="submit"
                  disabled={isSaving}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center"
                >
                  {isSaving ? (
                    <>
                      <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                      Zapisywanie...
                    </>
                  ) : (
                    <>
                      <Save className="w-5 h-5 mr-2" />
                      Zapisz produkt
                    </>
                  )}
                </button>
              </div>
            </form>
          </motion.div>
        </div>
      </div>
    </div>
  );
};

export default AdminProductModal;